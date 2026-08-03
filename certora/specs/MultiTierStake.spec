methods {
    function totalStaked() external returns (uint256) envfree;
    function stakeOf(address) external returns (uint256) envfree;
}

rule stakeIncreasesTotals(env e, uint256 amount, uint8 tier) {
    uint256 before = totalStaked();
    stake(e, amount, tier);
    assert totalStaked() >= before;
}

rule unstakeCannotExceedBalance(env e, uint256 amount) {
    uint256 bal = stakeOf(e.msg.sender);
    unstake@withrevert(e, amount);
    assert amount <= bal || lastReverted;
}