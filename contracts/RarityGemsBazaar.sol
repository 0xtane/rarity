// SPDX-License-Identifier: MIT
////////////////////////////////////////////////////////////////////////////////////////////
// ██████╗  █████╗ ██████╗ ██╗████████╗██╗   ██╗     ██████╗ ███████╗███╗   ███╗███████╗
// ██╔══██╗██╔══██╗██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝    ██╔════╝ ██╔════╝████╗ ████║██╔════╝
// ██████╔╝███████║██████╔╝██║   ██║    ╚████╔╝     ██║  ███╗█████╗  ██╔████╔██║███████╗
// ██╔══██╗██╔══██║██╔══██╗██║   ██║     ╚██╔╝      ██║   ██║██╔══╝  ██║╚██╔╝██║╚════██║
// ██║  ██║██║  ██║██║  ██║██║   ██║      ██║       ╚██████╔╝███████╗██║ ╚═╝ ██║███████║
// ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝      ╚═╝        ╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝
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

import "./token/ERC1155/IERC1155.sol";
import "./utils/math/SafeMath.sol";
import "./access/Ownable.sol";

contract RarityGemsBazaar is Ownable {
  using SafeMath for uint256;
  ///////////////////////////////////////////////////////////////
  // V1 of RarityGemsBazaar
  // I apologise for low quality of coding style/conventions
  ///////////////////////////////////////////////////////////////

  IERC1155 public rarityGemsContract = IERC1155(address(0x342EbF0A5ceC4404CcFF73a40f9c30288Fc72611)); // Initialises RarityGem contract

  bool _Lock = false; // reentrancyGuard

  // Maps accounts to mapping of gemID => with amountForSale
  mapping( address => mapping( uint => uint ) ) public amountsForSale;
  // Maps accounts to mapping of gemID => price per gem
  mapping( address => mapping( uint => uint ) ) public pricePerGem;

  address[] internal registeredSellers;
  address payable public bazaarKeeper;
  uint constant public bazaarKeeperFee = 1; // 1% fee on sell




  constructor() {
    bazaarKeeper = payable(msg.sender); // give deployer the role of
  }

  event ListingUpdated( address account, uint gemID, uint amountForSale, uint pricePerGem );
  event GemsPurchased( address buyer, address seller, uint gemID, uint pricePerGem , uint amount );
  event BazaarKeeperChanged( address oldKeeper, address newKeeper );

  modifier onlyBazaarKeeper {
    require( msg.sender == address(bazaarKeeper) ,"You are not the BazaarKeeper");
    _;
  }




  modifier reentrancyGuard {
    require( !_Lock, "Reentrancy attack!");
    _Lock = true;
    _;
    _Lock = false;
  }


  function getAllActiveSellers() public view returns(address[] memory) {
    address[] memory activeSellers = new address[](registeredSellers.length);
    uint i;
    uint k;
    uint counter = 0;
    for ( i=0; i<registeredSellers.length; i++) {
      for ( k=0; k<12; k++ ) {
        if ( amountsForSale[ registeredSellers[i] ][k] > 0 ) {
          activeSellers[counter] = registeredSellers[i];
          counter+=1;
        }
      }
    }
    return activeSellers;
  }

  function getActiveSellersForGemID( uint gemID ) public view returns(address[] memory) {
    address[] memory activeSellers = new address[](registeredSellers.length);
    uint i;
    uint counter = 0;
    for ( i=0; i<registeredSellers.length; i++) {
      if ( amountsForSale[ registeredSellers[i] ][gemID] > 0 ) {
        activeSellers[counter] = registeredSellers[i] ;
        counter+=1;
      }
    }
    return activeSellers;
  }

  function isRegistered(address account) public view returns(bool) {
    uint i;
    for ( i = 0; i<registeredSellers.length;i++ ) {
      if ( registeredSellers[i]==account ) {
        return true;
      }
    }
    return false;
  }


  // Sets how much gems of a kind a seller is willing to sell and for what price
  function updateListing(uint gemID, uint amountForSale_, uint pricePerGem_ ) external  {
    if (!isRegistered(msg.sender) ) {
      registeredSellers.push(msg.sender);
    }
    require( rarityGemsContract.isApprovedForAll( msg.sender , address(this) ), "Authorize Bazaar to handle your Gems first");
     _updateListing(msg.sender, gemID, amountForSale_, pricePerGem_);
  }

  function _updateListing( address seller, uint gemID, uint amount, uint price ) internal {
    amountsForSale[seller][gemID] = amount;
    pricePerGem[seller][gemID] = price;
    emit ListingUpdated(seller, gemID, amount, price);
  }

  // purchase from who, what gem and how many / msg.value should be amount * price
  function purchaseGems(address seller, uint gemID, uint amount_ ) external payable reentrancyGuard {
    require( amount_ > 0, "Amount needs to be a positive number");
    require( amountsForSale[seller][gemID] >= amount_ , "Seller does not have enough gems in for sale");
    require( rarityGemsContract.balanceOf( seller,gemID ) >= amount_, "Seller does not have enough gems in stock");
    require( rarityGemsContract.isApprovedForAll(seller , address(this)), "Seller has not authorized bazaar to handle their gems");
    require( msg.value == pricePerGem[seller][gemID].mul(amount_), "Please send exact amount");

    rarityGemsContract.safeTransferFrom( seller, msg.sender, gemID, amount_, abi.encodePacked("Purchased gems from the Bazaar"));

    uint bazaarKeeperCut = msg.value.mul(bazaarKeeperFee).div(100); // Bazaarkeeper fee is 1%
    uint sellerCut = msg.value.sub(bazaarKeeperCut); // Seller cut is 99% of sale

    payable(seller).transfer(sellerCut);

    _updateListing(seller, gemID, amountsForSale[seller][gemID].sub(amount_), pricePerGem[seller][gemID]);

    emit GemsPurchased(msg.sender,seller,gemID,pricePerGem[seller][gemID],amount_);
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
