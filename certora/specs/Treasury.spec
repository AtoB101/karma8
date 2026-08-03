methods {
    function feeBps() external returns (uint256) envfree;
    function splitRatios() external returns (uint256,uint256,uint256,uint256) envfree;
    function enableRevenueMode() external returns (bool) envfree;
}

rule feeBpsImmutable() {
    assert feeBps() == 20;
}

rule splitRatiosImmutable() {
    uint256 a; uint256 b; uint256 c; uint256 d;
    a,b,c,d = splitRatios();
    assert a == 40 && b == 30 && c == 20 && d == 10;
    assert a + b + c + d == 100;
}

rule distributeRequiresRevenueMode(env e) {
    require !enableRevenueMode();
    distributeNow@withrevert(e);
    assert lastReverted;
}