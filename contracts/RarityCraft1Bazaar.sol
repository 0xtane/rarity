// SPDX-License-Identifier: MIT
////////////////////////////////////////////////////////////////////////////////////////////
// ██████╗  █████╗ ██████╗ ██╗████████╗██╗   ██╗
// ██╔══██╗██╔══██╗██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
// ██████╔╝███████║██████╔╝██║   ██║    ╚████╔╝
// ██╔══██╗██╔══██║██╔══██╗██║   ██║     ╚██╔╝
// ██║  ██║██║  ██║██║  ██║██║   ██║      ██║
// ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝      ╚═╝
//
// ██████╗  █████╗ ███████╗ █████╗  █████╗ ██████╗
// ██╔══██╗██╔══██╗╚══███╔╝██╔══██╗██╔══██╗██╔══██╗
// ██████╔╝███████║  ███╔╝ ███████║███████║██████╔╝
// ██╔══██╗██╔══██║ ███╔╝  ██╔══██║██╔══██║██╔══██╗
// ██████╔╝██║  ██║███████╗██║  ██║██║  ██║██║  ██║
// ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝
/////////////////////////////////////////////////////////////////////////////////////////////
// Disclaimer: use at your own risk/will

pragma solidity ^0.8.0;

import "./access/Ownable.sol";
import "./IRarity.sol";

interface ICraft1 {
  function transferFrom(uint,uint,uint,uint) external returns(bool);
  function balanceOf(uint) external view returns(uint);
  function allowance(uint,uint) external view returns (uint);
}

contract RarityCraft1Bazaar is Ownable {
  ICraft1 public constant craft1Contract = ICraft1(0x2A0F1cB17680161cF255348dDFDeE94ea8Ca196A);
  IRarity public constant rarityContract = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);

  bool _Lock = false; // reentrancyGuard


  mapping( uint => uint )  public amountsForSale;
  mapping( uint => uint ) public pricePerMat;

  uint[] internal registeredSellers;
  address payable public bazaarKeeper;
  uint constant public bazaarKeeperFee = 1; // 1% fee on sell

  uint public bazaarKeeperSummoner;


  constructor() {
    bazaarKeeper = payable(msg.sender); // give deployer the role of bazaarkeeper
    bazaarKeeperSummoner = rarityContract.next_summoner();
    rarityContract.summon(2);
  }

  event ListingUpdated( address indexed account ,uint indexed summonerID, uint indexed , uint  price );
  event Craft1MaterialsPurchased( uint indexed buyer, uint indexed seller, uint indexed price , uint amount );
  event BazaarKeeperChanged( address indexed oldKeeper, address indexed newKeeper );

  modifier onlyBazaarKeeper {
    require( msg.sender == address(bazaarKeeper) ,"You are not the BazaarKeeper");
    _;
  }

  modifier ownerOrApproved(uint summonerID) {
    require( rarityContract.ownerOf(summonerID) == msg.sender || rarityContract.getApproved(summonerID) == msg.sender , "Neither owner nor approved");
    _;
  }

  modifier reentrancyGuard {
    require( !_Lock, "Reentrancy attack!");
    _Lock = true;
    _;
    _Lock = false;
  }


  function getAllListings()  external view returns(uint[] memory,uint[] memory,uint[] memory,uint[] memory) {
    uint[] memory activeSellers =  getActiveSellers();
    uint[] memory resultsSellerIDs = new uint[](activeSellers.length);
    uint[] memory resultsPrices = new uint[](activeSellers.length);
    uint[] memory resultsAmounts = new uint[](activeSellers.length);
    uint[] memory resultsBalances = new uint[](activeSellers.length);

    uint balance;
    uint counter;
    for (uint i=0;i<activeSellers.length;i++) {
      if ( activeSellers[i] != 0 ) {
        balance = craft1Contract.balanceOf(activeSellers[i]);
        if ( balance > 0 ) {
          resultsSellerIDs[counter]=activeSellers[i];
          resultsPrices[counter]=pricePerMat[activeSellers[i]];
          resultsAmounts[counter]=amountsForSale[activeSellers[i]];
          resultsBalances[counter]=balance;
          counter+=1;
        }
      }
    }
    return ( resultsSellerIDs ,resultsPrices , resultsAmounts , resultsBalances );
  }

  function getActiveSellers( ) public view returns(uint[] memory) {
    uint[] memory activeSellers = new uint[](registeredSellers.length);
    uint i;
    uint counter = 0;
    for ( i=0; i<registeredSellers.length; i++) {
      if ( amountsForSale[ registeredSellers[i] ] > 0 ) {
        activeSellers[counter] = registeredSellers[i] ;
        counter+=1;
      }
    }
    return activeSellers;
  }

  function isRegistered(uint account) public view returns(bool) {
    uint i;
    for ( i = 0; i<registeredSellers.length;i++ ) {
      if ( registeredSellers[i]==account ) {
        return true;
      }
    }
    return false;
  }


  function updateListing(uint summonerID, uint amountForSale, uint price ) external
    ownerOrApproved(summonerID)
  {
    if (!isRegistered(summonerID) ) {
      registeredSellers.push(summonerID);
    }
    require( craft1Contract.allowance( summonerID , bazaarKeeperSummoner )>=amountForSale, "Authorize BazaarKeeper to handle your materials first");
    _updateListing(summonerID,amountForSale,price);
  }

  function _updateListing( uint sellerID, uint amount, uint price ) internal {
    amountsForSale[sellerID] = amount;
    pricePerMat[sellerID] = price;
    emit ListingUpdated(msg.sender,sellerID,amount,price);
  }


  function purchaseMats(uint sellerID, uint buyerID, uint amount_ ) external payable reentrancyGuard {
    require( amount_ > 0, "Amount needs to be a positive number");
    require( amountsForSale[sellerID] >= amount_ , "Seller does not have enough materials in for sale");
    require( craft1Contract.balanceOf( sellerID ) >= amount_, "Seller does not have enough materials in stock");
    require( craft1Contract.allowance(sellerID , bazaarKeeperSummoner)>=amount_, "Seller has not authorized bazaar to handle their materials");
    require( msg.value == pricePerMat[sellerID] * amount_, "Please send exact amount");

    craft1Contract.transferFrom( bazaarKeeperSummoner, sellerID, buyerID, amount_);

    uint bazaarKeeperCut = ( msg.value * bazaarKeeperFee) / 100; // Bazaarkeeper fee is 1%
    uint sellerCut = msg.value - bazaarKeeperCut; // Seller cut is 99% of sale

    address payable sellerAddress = payable(rarityContract.ownerOf(sellerID));
    sellerAddress.transfer(sellerCut);

    _updateListing(sellerID, amountsForSale[sellerID] - amount_, pricePerMat[sellerID]);

    emit Craft1MaterialsPurchased(buyerID,sellerID,pricePerMat[sellerID],amount_);
  }

  function setBazaarKeeper(address newKeeper_) external onlyBazaarKeeper {
    emit BazaarKeeperChanged(address(bazaarKeeper) , newKeeper_);
    bazaarKeeper = payable(newKeeper_);
  }

  // withdraws fees generated from  1% fee
  function withdrawFees() external onlyBazaarKeeper {
    payable(msg.sender).transfer(address(this).balance);
  }

}
