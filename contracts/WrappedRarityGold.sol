// SPDX-License-Identifier: MIT
////////////////////////////////////////////////////////////////////////////////////////////
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IRarity.sol";
import "./IRarityGold.sol";

contract WrappedRarityGold is ERC20("Wrapped Rarity Gold","WRGOLD") {

  IRarity rarityContract = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
  IRarityGold rarityGoldContract = IRarityGold(0x2069B76Afe6b734Fb65D1d099E7ec64ee9CC76B2);
  uint public _Treasurer; // ID of the summoner which this contract holds as a way to keep gold locked


  event GoldGotWrapped(uint indexed summonerID,uint amount);
  event GoldGotUnwrapped(uint amount,uint indexed toSummonerID);

  constructor() {
    _Treasurer = rarityContract.next_summoner();
    rarityContract.summon(2); // Bardie barda bardooo
  }

  modifier ownerOrApproved(uint summonerID) {
    require( rarityContract.ownerOf(summonerID) == msg.sender || rarityContract.getApproved(summonerID) == msg.sender , "Neither owner nor approved");
    _;
  }

  modifier hasEnoughAndApproved(uint summonerID, uint amount) {
    require( rarityGoldContract.balanceOf(summonerID) >= amount ,"Summoner doesnt have enough gold");
    require( rarityGoldContract.allowance(summonerID,_Treasurer) >= amount, "Not enough allowance to Treasurer");
    _;
  }

  // yes i know that these modifiers are not needed since transferFrom will revert anyway
  function wrap(uint summonerID , uint amountToWrap) external
    ownerOrApproved(summonerID)
    hasEnoughAndApproved(summonerID , amountToWrap)
  {
    require( rarityGoldContract.transferFrom(_Treasurer, summonerID, _Treasurer, amountToWrap) , "TransferFrom of gold failed");
    _mint(msg.sender,amountToWrap);

    emit GoldGotWrapped(summonerID,amountToWrap);
  }

  function unwrap( uint amountToUnwrap, uint toSummonerID ) external {
    _burn( msg.sender, amountToUnwrap );
    require( rarityGoldContract.transfer( _Treasurer, toSummonerID , amountToUnwrap ), "Transfer of gold failed");

    emit GoldGotUnwrapped( amountToUnwrap, toSummonerID );
  }

}
