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


import "./IRarityGemsBazaar.sol";
import "./token/ERC1155/IERC1155.sol";

contract BazaarListingQuery {
  IRarityGemsBazaar bazaarContract = IRarityGemsBazaar(0xAF91aF7D79427BaFd9444660EFF325F36Cccb176);
  IERC1155 rarityGemsContract = IERC1155(0x342EbF0A5ceC4404CcFF73a40f9c30288Fc72611);

  function getListingsForGemID( uint gemID )  public view returns(address[] memory,uint[] memory,uint[] memory,uint[] memory) {
    address[] memory activeSellers =  bazaarContract.getActiveSellersForGemID(gemID);
    address[] memory resultsAddresses = new address[](activeSellers.length);
    uint[] memory resultsPrices = new uint[](activeSellers.length);
    uint[] memory resultsAmounts = new uint[](activeSellers.length);
    uint[] memory resultsBalances = new uint[](activeSellers.length);

    uint balance;
    uint i;
    uint counter = 0;
    for (i=0;i<activeSellers.length;i++) {
      if ( activeSellers[i] != address(0x0000000000000000000000000000000000000000) ) {
        balance = rarityGemsContract.balanceOf(activeSellers[i],gemID);
        if ( balance > 0 ) {
          resultsAddresses[counter]=activeSellers[i];
          resultsPrices[counter]=bazaarContract.pricePerGem(activeSellers[i],gemID);
          resultsAmounts[counter]=bazaarContract.amountsForSale(activeSellers[i],gemID);
          resultsBalances[counter]=balance;
          counter+=1;
        }
      }
    }
    return ( resultsAddresses ,resultsPrices , resultsAmounts , resultsBalances );
  }
}
