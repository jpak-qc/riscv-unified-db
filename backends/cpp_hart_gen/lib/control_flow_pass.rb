# frozen_string_literal: true

# pass to see if node sets the PC
# does _NOT_ count exceptions

module Idl
  # The same helper function can be reached from many instruction bodies. Cache
  # its control-flow result so generation scales with the call graph, not the
  # number of call sites. The sentinel also breaks recursive call graphs.
  CONTROL_FLOW_IN_PROGRESS = Object.new

  class AstNode
    def control_flow?(symtab)
      if children.empty?
        false
      else
        children.any? { |child| child.control_flow?(symtab) }
      end
    end
  end

  class PcAssignmentAst
    def control_flow?(symtab) = true
  end

  class FunctionCallExpressionAst
    def control_flow?(symtab)
      return true if children.any? { |child| child.control_flow?(symtab) }

      return false if name =~ /^raise.*$/ # we don't count exceptions

      func_def_type = func_type(symtab)

      return false if func_def_type.builtin? || func_def_type.generated?

      cache = Thread.current[:idl_control_flow_cache] ||= {}
      function = func_def_type.func_def_ast
      cached = cache[function]
      return cached if cached == true || cached == false
      return false if cached == CONTROL_FLOW_IN_PROGRESS

      cache[function] = CONTROL_FLOW_IN_PROGRESS
      begin
        cache[function] = func_def_type.body.control_flow?(symtab)
      rescue StandardError
        cache.delete(function)
        raise
      end
    end
  end
end
