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


interface IC1Bazaar  {
  function getActiveSellers() external view returns(uint[] memory);
  function pricePerMat(uint) external view returns(uint);
  function amountsForSale(uint) external view returns(uint);
}
interface IRarity {
  function ownerOf(uint) external view returns(address);
}

contract Craft1BazaarQuery {
  IC1Bazaar c1BazaarContract = IC1Bazaar(0x946078c3f2417B18a0aA17d7981167c13e4098E9);
  IRarity rarityContract = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);

  function getListingsForAddress(address account) public view returns(uint[] memory,uint[] memory,uint[] memory) {
    uint[] memory activeSellers = c1BazaarContract.getActiveSellers();
    uint[] memory resultsSummonerIDs = new uint[](activeSellers.length);
    uint[] memory resultsPrices = new uint[](activeSellers.length);
    uint[] memory resultsAmounts = new uint[](activeSellers.length);

    address owner;
    uint counter = 0;
    for (uint i=0;i<activeSellers.length;i++) {
      if ( activeSellers[i] != 0 ) {
        owner = rarityContract.ownerOf(activeSellers[i]);
        if ( owner == account ) {
          resultsSummonerIDs[counter]=activeSellers[i];
          resultsPrices[counter]=c1BazaarContract.pricePerMat(activeSellers[i]);
          resultsAmounts[counter]=c1BazaarContract.amountsForSale(activeSellers[i]);
          counter+=1;
        }
      }
    }
    return ( resultsSummonerIDs ,resultsPrices , resultsAmounts  );
  }
}
