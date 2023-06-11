// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
import "test/helper/CompoundTestSetUp.sol";
import "compound-protocol/contracts/Comptroller.sol";
import { CErc20 } from "compound-protocol/contracts/CErc20.sol";
import { CToken } from "compound-protocol/contracts/CToken.sol";
import { CTokenInterface } from "compound-protocol/contracts/CTokenInterfaces.sol";
import "forge-std/console.sol";

contract CompoundTest is CompoundTestSetUp{
    Comptroller comptrollerProxy;
    CErc20 cTokenA;
    CErc20 cTokenB;

    function setUp() public override {
        super.setUp();
        comptrollerProxy = Comptroller(address(unitroller));
        cTokenA = CErc20(address(cDelegatorA));
        cTokenB = CErc20(address(cDelegatorB));
        vm.label(address(comptrollerProxy), "comptrollerProxy");
        vm.label(address(cTokenA), "cTokenA");
        vm.label(address(cTokenB), "cTokenB");

        
        // put cTokenA and cTokenB on the market
        vm.startPrank(admin);
        comptrollerProxy._supportMarket(CToken(address(cDelegatorA)));
        comptrollerProxy._supportMarket(CToken(address(cDelegatorB)));
        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        uint256 amount = 100 * 10**18;
        // mint underlying tokenA to user1
        tokenA.mint(user1, amount);
        assertEq(tokenA.balanceOf(user1), amount);

        vm.startPrank(user1);
        // approve
        assertTrue(tokenA.approve(address(cTokenA), amount));
        // mint CTokenA and should be 1:1 
        cTokenA.mint(amount);
        assertEq(cTokenA.balanceOf(user1), amount);
        // redeem TokenA and amount should be the same
        cTokenA.redeem(amount);
        assertEq(tokenA.balanceOf(user1), amount);
        
        vm.stopPrank();
    }

    function testBorrowAndRepay() public {
        // mint tokenB to user1
        uint256 amountB = 1 * 10**tokenB.decimals();
        tokenB.mint(user1, amountB);
        assertEq(tokenB.balanceOf(user1), amountB);

        // set price for tokenA and tokenB
        uint256 tokenAPriceMantissa = 1 * 10**18;
        uint256 tokenBPriceMantissa = 100 * 10**18;
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPriceMantissa);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenA))), tokenAPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenB))), tokenBPriceMantissa);
        
        // admin set cTokenB's collateralFactor to 50%
        vm.prank(admin);
        assertEq(
            comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)),0.5 * 10**18),
            0 // no error
        );

        // user2 add tokenA into protocol
        vm.startPrank(user2);
        uint256 amountA = 100 * 10**tokenA.decimals();
        tokenA.mint(user2, amountA);
        assertTrue(tokenA.approve(address(cTokenA), amountA));
        cTokenA.mint(amountA);
        vm.stopPrank();

        // user1 mint cTokenB
        vm.startPrank(user1);
        assertTrue(tokenB.approve(address(cTokenB), amountB));
        cTokenB.mint(amountB);

        // user1 add cTokenB to collateral
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10**18);
        
        // user1 borrow tokenA
        uint256 borrowAmount = 50 * 10**tokenA.decimals();
        cTokenA.borrow(borrowAmount);
        assertEq(tokenA.balanceOf(user1), borrowAmount);

        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 0);

        // user1 repay tokenA
        tokenA.approve(address(cTokenA), borrowAmount);
        assertEq(cTokenA.repayBorrow(type(uint256).max), 0);
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10**18);
        vm.stopPrank();
    }

    function testDecreaseCollateralFactorAndLiquidate() public {
        // mint tokenB to user1
        uint256 amountB = 1 * 10**tokenB.decimals();
        tokenB.mint(user1, amountB);
        assertEq(tokenB.balanceOf(user1), amountB);

        // set price for tokenA and tokenB
        uint256 tokenAPriceMantissa = 1 * 10**18;
        uint256 tokenBPriceMantissa = 100 * 10**18;
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPriceMantissa);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenA))), tokenAPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenB))), tokenBPriceMantissa);
        
        // admin set cTokenB's collateralFactor to 50%
        vm.prank(admin);
        assertEq(
            comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)),0.5 * 10**18),
            0 // no error
        );

        // user2 add tokenA into protocol
        vm.startPrank(user2);
        uint256 amountA = 100 * 10**tokenA.decimals();
        tokenA.mint(user2, amountA);
        assertTrue(tokenA.approve(address(cTokenA), amountA));
        cTokenA.mint(amountA);
        vm.stopPrank();

        // user1 mint cTokenB
        vm.startPrank(user1);
        assertTrue(tokenB.approve(address(cTokenB), amountB));
        cTokenB.mint(amountB);

        // user1 add cTokenB to collateral
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10**18);
        
        // user1 borrow tokenA
        uint256 borrowAmount = 50 * 10**tokenA.decimals();
        cTokenA.borrow(borrowAmount);
        assertEq(tokenA.balanceOf(user1), borrowAmount);

        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 0);
        vm.stopPrank();

        // admin decrease collateral factor
        vm.startPrank(admin);
        assertEq(
            comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)),0.3 * 10**18),
            0 // no error
        );
        // admin set CloseFactor = 50% and LiquidationIncentive = 8%
        assertEq(
            comptrollerProxy._setCloseFactor(0.5 * 10**18),
            0 // no error
        );
        assertEq(
            // notice that this should be 108% 
            comptrollerProxy._setLiquidationIncentive(1.08 * 10**18),
            0 // no error
        );
        vm.stopPrank();
        
        // user1 shortfall should be greater than 0 now
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertGt(shortfall, 0);

        // user2 liquidate
        // repayAmount = closeFactor * borrowBalance = 50% * 50 = 25
        vm.startPrank(user2);
        uint256 repayAmount = 25 * 10**18;
        // user2 need tokenA before liquidate
        tokenA.mint(user2, repayAmount);
        tokenA.approve(address(cTokenA), repayAmount);
        assertEq(
            cTokenA.liquidateBorrow(user1, repayAmount, CTokenInterface(cTokenB)),
            0
        );
        // seizeTokens = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
        //             = 25 * 1.08 * $1 / ($100 * 1) = 0.27
        // goes to protocol reserve = 0.27 * 2.8% = 0.00756
        // goes to liquidator = 0.27 - 0.00756 = 0.26244
        assertEq(cTokenB.balanceOf(user2), 0.26244 * 10**18);
        assertEq(cTokenB.totalReserves(), 0.00756 * 10**18);
        vm.stopPrank();
    }

    function testDecreasePriceAndLiquidate() public {
        // mint tokenB to user1
        uint256 amountB = 1 * 10**tokenB.decimals();
        tokenB.mint(user1, amountB);
        assertEq(tokenB.balanceOf(user1), amountB);

        // set price for tokenA and tokenB
        uint256 tokenAPriceMantissa = 1 * 10**18;
        uint256 tokenBPriceMantissa = 100 * 10**18;
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPriceMantissa);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenA))), tokenAPriceMantissa);
        assertEq(oracle.getUnderlyingPrice(CToken(address(cTokenB))), tokenBPriceMantissa);
        
        // admin set cTokenB's collateralFactor to 50%
        vm.prank(admin);
        assertEq(
            comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)),0.5 * 10**18),
            0 // no error
        );

        // user2 add tokenA into protocol
        vm.startPrank(user2);
        uint256 amountA = 100 * 10**tokenA.decimals();
        tokenA.mint(user2, amountA);
        assertTrue(tokenA.approve(address(cTokenA), amountA));
        cTokenA.mint(amountA);
        vm.stopPrank();

        // user1 mint cTokenB
        vm.startPrank(user1);
        assertTrue(tokenB.approve(address(cTokenB), amountB));
        cTokenB.mint(amountB);

        // user1 add cTokenB to collateral
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10**18);
        
        // user1 borrow tokenA
        uint256 borrowAmount = 50 * 10**tokenA.decimals();
        cTokenA.borrow(borrowAmount);
        assertEq(tokenA.balanceOf(user1), borrowAmount);

        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertEq(liquidity, 0);
        vm.stopPrank();

        // tokenB's price drop 20%
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPriceMantissa * 80 / 100);

        // admin set CloseFactor = 50% and LiquidationIncentive = 8%
        vm.startPrank(admin);
        assertEq(
            comptrollerProxy._setCloseFactor(0.5 * 10**18),
            0 // no error
        );
        assertEq(
            // notice that this should be 108% 
            comptrollerProxy._setLiquidationIncentive(1.08 * 10**18),
            0 // no error
        );
        vm.stopPrank();

        // user1 shortfall should be greater than 0 now
        (, liquidity, shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertGt(shortfall, 0);

        // user2 liquidate
        // repayAmount = closeFactor * borrowBalance = 50% * 50 = 25
        vm.startPrank(user2);
        uint256 repayAmount = 25 * 10**18;
        // user2 need tokenA before liquidate
        tokenA.mint(user2, repayAmount);
        tokenA.approve(address(cTokenA), repayAmount);
        assertEq(
            cTokenA.liquidateBorrow(user1, repayAmount, CTokenInterface(cTokenB)),
            0
        );
        // seizeTokens = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
        //             = 25 * 1.08 * $1 / ($80 * 1) = 0.3375
        // goes to protocol reserve = 0.3375 * 2.8% = 0.00945
        // goes to liquidator = 0.3375 - 0.00945 = 0.32805
        assertEq(cTokenB.balanceOf(user2), 0.32805 * 10**18);
        assertEq(cTokenB.totalReserves(), 0.00945 * 10**18);
        vm.stopPrank();
    }


}