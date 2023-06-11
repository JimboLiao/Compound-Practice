pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../../contracts/Underlying.sol";
import "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "compound-protocol/contracts/CErc20Delegate.sol";
import "compound-protocol/contracts/CErc20Delegator.sol";
import "compound-protocol/contracts/ComptrollerInterface.sol";
import "compound-protocol/contracts/Comptroller.sol";
import "compound-protocol/contracts/Unitroller.sol";
import "compound-protocol/contracts/SimplePriceOracle.sol";
import "compound-protocol/contracts/PriceOracle.sol";


contract CompoundTestSetUp is Test {
    // accounts for testing
    address user1;
    address user2;
    address admin;
    // cDelegatorA and cDelegatorB
    Underlying tokenA;
    Underlying tokenB;
    WhitePaperInterestRateModel interestRateModelA;
    WhitePaperInterestRateModel interestRateModelB;
    CErc20Delegate cErc20DelegateA;
    CErc20Delegate cErc20DelegateB;
    CErc20Delegator cDelegatorA;
    CErc20Delegator cDelegatorB;
    // oracle
    SimplePriceOracle oracle;
    // every cToken use the same comptroller
    Comptroller comptroller;
    Unitroller unitroller;

    /*  
        SetUp() :
        deploy 2 ERC20 : tokenA, tokenB
            decimals = 18
        deploy 2 cErc20Delegator : cDelegatorA, cDelegatorB
            interest rate = 0%
            initial exchange rate = 1:1
            use SimplePriceOracle as oracle
    */
    function setUp() public virtual{
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        // admin
        admin = makeAddr("admin");
        vm.startPrank(admin);

        // ERC20 tokenA and tokenB
        tokenA = new Underlying("TokenA", "TKA", 18);
        tokenB = new Underlying("TokenB", "TKB", 18);

        // Comptroller and Unitroller
        // Must be admin to create comptroller and unitroller
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        uint errorCode = unitroller._setPendingImplementation(address(comptroller));
        require(errorCode == 0, "failed to set pendingImplementation");
        comptroller._become(unitroller);
        
        // oracle
        oracle = new SimplePriceOracle();
        Comptroller(address(unitroller))._setPriceOracle(PriceOracle(oracle));

        // InterestRateModel -> use WhitePaperInterestRateModel, 0% rate
        interestRateModelA = new WhitePaperInterestRateModel(0, 0);
        interestRateModelB = new WhitePaperInterestRateModel(0, 0);

        // implementation_ -> CErc20Delegate
        cErc20DelegateA = new CErc20Delegate();
        cErc20DelegateB = new CErc20Delegate();

        // set cERC20Delegators
        cDelegatorA = new CErc20Delegator(
            address(tokenA),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(interestRateModelA)),
            10**18,
            "Compound TokenA",
            "cTKA",
            18,
            payable(admin),
            address(cErc20DelegateA),
            ''
        );

        cDelegatorB = new CErc20Delegator(
            address(tokenB),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(interestRateModelB)),
            10**18,
            "Compound TokenB",
            "cTKB",
            18,
            payable(admin),
            address(cErc20DelegateB),
            ''
        );

        vm.stopPrank();
    }
}