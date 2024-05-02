// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IConfig} from "./interface/IConfig.sol";

contract LaunchpadConfig is IConfig, OwnableUpgradeable {

    address public signer;
    address public eventProvider;
    address public launchpadImplement;
    address public orochiAggregator;
    address public orochiProvider;
    address public orochiProvider2;

    function initialize(
        address _signer,
        address _eventProvider,
        address _launchpadImplement,
        address _orochiAggregator,
        address _orochiProvider,
        address _orochiProvider2
    ) public initializer {
        __Ownable_init();
        signer = _signer;
        eventProvider = _eventProvider;
        launchpadImplement = _launchpadImplement;
        orochiAggregator = _orochiAggregator;
        orochiProvider = _orochiProvider;
        orochiProvider2 = _orochiProvider2;
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function setEventProvider(address _eventProvider) external onlyOwner {
        eventProvider = _eventProvider;
    }

    function setLaunchpadImplement(address _launchpadImplement) external onlyOwner {
        launchpadImplement = _launchpadImplement;
    }

    function setOrochiProvider(address _orochiProvider, address _orochiProvider2) external onlyOwner {
        orochiProvider = _orochiProvider;
        orochiProvider2 = _orochiProvider2;
    }

    function setOrochiAggregator(address _orochiAggregator) external onlyOwner {
        orochiAggregator = _orochiAggregator;
    }
}