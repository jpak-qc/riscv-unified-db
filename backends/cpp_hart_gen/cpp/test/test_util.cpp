
#include <catch2/catch_test_macros.hpp>
#include <udb/defines.hpp>
#include <udb/util.hpp>

using namespace udb;

TEST_CASE("concat", "[util]") {
  Bits<4> a{0x1};
  Bits<4> b{0x2};
  Bits<4> c{0x3};
  REQUIRE(concat(a, b, c) == 0x123_b);
}

TEST_CASE("bit_insert supports runtime-width targets", "[util]") {
  _PossiblyUnknownRuntimeBits<256, false> target{0_b, 256_b};

  const auto result = bit_insert<31, 0, 256>(target, 0xdeadbeef_b);

  REQUIRE(result.width() == 256);
  REQUIRE(result == 0xdeadbeef_b);
}
