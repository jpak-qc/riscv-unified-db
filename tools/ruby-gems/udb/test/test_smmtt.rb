# Copyright (c) RISC-V International
# SPDX-License-Identifier: CC-BY-4.0

# typed: false
# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "json"
require "json_schemer"
require "tmpdir"
require "yaml"

require "udb/cfg_arch"
require "udb/resolver"

class TestSmmtt < Minitest::Test
  include Udb

  EXTENSIONS = %w[
    Smsd Smmpt34 Smmpt43 Smmpt52 Smmpt64 Smsdia Smgeien Ssgeien
    Smqosid Smsdqosid Svpams Smsdedbga Smsdetrca
  ].freeze

  PARAMETERS = %w[
    SDID_WIDTH SIDN_MAX MGEILEN QRID_WIDTH PAMS_ECID_WIDTH
  ].freeze

  def setup
    @gen_dir = Dir.mktmpdir
    @resolver = Udb::Resolver.new(Udb.repo_root, gen_path_override: Pathname.new(@gen_dir), quiet: true)
    @arch = @resolver.cfg_arch_for("_")
  end

  def teardown
    FileUtils.rm_rf @gen_dir
  end

  def test_all_smmtt_extension_families_are_resolvable
    EXTENSIONS.each do |name|
      ext = @arch.extension_version(name, "0.9.0")
      refute_nil ext, "#{name} v0.9.0 must be resolvable"
      assert_equal name, ext.name
    end
  end

  def test_smmtt_parameters_are_resolvable
    PARAMETERS.each do |name|
      refute_nil @arch.param(name), "#{name} must be a declared Smmtt parameter"
    end
  end

  def test_mpt_interrupt_and_qos_csr_families_are_resolvable
    {
      "mmpt" => %w[MODE SDID PPN],
      "msdcfg" => %w[SIDN SEDA SETA SSRM SSMM SRL SML],
      "msideip" => ["INTERRUPTS"],
      "msideiph" => ["INTERRUPTS"],
      "msideie" => ["INTERRUPTS"],
      "msideieh" => ["INTERRUPTS"],
      "mgeien" => %w[A GIF],
      "mrmcfg" => %w[RCID MCID QRID],
      "mnrmcfg" => %w[RCID MCID QRID]
    }.each do |csr_name, fields|
      csr = @arch.csr(csr_name)
      refute_nil csr, "#{csr_name} must be resolvable"
      fields.each { |field| refute_nil csr.field(field), "#{csr_name}.#{field} must be defined" }
    end
  end

  def test_cross_csr_fields_model_smmtt_controls
    assert @arch.csr("menvcfg").field?("PAMSE")
    assert @arch.csr("henvcfg").field?("PAMSE")
    assert @arch.csr("mip").field?("MSDEIP")
    assert @arch.csr("mie").field?("MSDEIE")
    assert @arch.csr("mideleg").field?("MSDEI")
    assert @arch.csr("sip").field?("MSDEIP")
    assert @arch.csr("sie").field?("MSDEIE")

    rcid_write = @arch.csr("srmcfg").field("RCID").data.fetch("sw_write(csr_value)")
    mcid_write = @arch.csr("srmcfg").field("MCID").data.fetch("sw_write(csr_value)")
    assert_includes rcid_write, "Smsdqosid"
    assert_includes rcid_write, "msdcfg"
    assert_includes mcid_write, "Smsdqosid"
    assert_includes mcid_write, "msdcfg"

    msideieh_write = @arch.csr("msideieh").field("INTERRUPTS").data.fetch("sw_write(csr_value)")
    assert_includes msideieh_write, "SIDN_MAX"
  end

  def test_svpams_conflicts_with_svrsw60t59b
    cfg = <<~YAML
      $schema: config_schema.json#
      kind: architecture configuration
      type: partially configured
      name: smmtt-pams-conflict
      description: Check Svpams PTE bit ownership
      mandatory_extensions:
        - name: Svpams
          version: ">= 0"
        - name: Svrsw60t59b
          version: ">= 0"
    YAML

    Tempfile.create(["smmtt", ".yaml"]) do |file|
      file.write(cfg)
      file.flush
      result = @resolver.cfg_arch_for(Pathname.new(file.path)).valid
      refute result.valid
      assert result.reasons.any? { |reason| reason.include?("Mandatory extension requirements conflict") }
    end
  end

  def test_iompt_checker_register_block_validates_against_non_isa_schema
    schema_path = Udb.repo_root / "spec" / "schemas" / "non_isa_schema.json"
    schema_dir = schema_path.parent
    schemer = JSONSchemer.schema(
      JSON.parse(File.read(schema_path)),
      ref_resolver: proc { |uri|
        schema = JSON.parse(File.read(schema_dir / File.basename(uri.path)))
        schema["definitions"] = schema["$defs"] if schema["$defs"] && !schema.key?("definitions")
        schema
      }
    )
    data = YAML.load_file(Udb.repo_root / "spec" / "std" / "non_isa" / "IomptChecker.yaml")
    assert_empty schemer.validate(data).to_a
  end
end
