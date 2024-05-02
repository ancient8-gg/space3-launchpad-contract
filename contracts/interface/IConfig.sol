// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IConfig {
    function setSigner(address _signer) external;

    function setEventProvider(address _eventProvider) external;

    function setLaunchpadImplement(address _launchpadImplement) external;

    function setOrochiProvider(address _orochiProvider, address _orochiProvider2) external;

    function setOrochiAggregator(address _orochiAggregator) external;

    function signer() external view returns (address);

    function eventProvider() external view returns (address);

    function launchpadImplement() external view returns (address);

    function orochiProvider() external view returns (address);

    function orochiProvider2() external view returns (address);

    function orochiAggregator() external view returns (address);
}
