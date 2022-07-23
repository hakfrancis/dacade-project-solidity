// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShowMax is Ownable, ERC20 {
    // keep track of movies serial number
    uint256 internal serial;

    // user details
    struct User {
        uint256 tokensPurchased;
        string[] moviesViewed;
    }

    // movie details
    struct Movie {
        uint256 serialNo;
        string name;
        string description;
        uint256 length;
        uint256 rates;
        uint256 rateCount;
        uint256 timesViewed;
        uint256 baseValue;
        bool active;
    }

    // mapping to keep track of all Movies
    mapping(uint256 => Movie) internal movies;
    // mapping to keep track of all users
    mapping(address => User) internal users;
    // mapping to keep track of movies user has already rated to prevent rating multiple times
    mapping(uint256 => mapping(address => bool)) internal rated;

    // mint "_quantity" amount of token and set as total supply
    // Send token to contract after minting
    constructor(uint256 _quantity) ERC20("ShowMax Studios", "SMS") {
        address _to = address(this);
        _mint(_to, _quantity);
    }

    // function to get the value of a token in ethers
    function getValue(uint256 _quantity) internal pure returns (uint256) {
        return _quantity * 10**18;
    }

    // function to get the calculated value of Movie
    // Increment movie value by 10% for every view
    function calculateValue(uint256 _movieSerial)
        public
        view
        returns (uint256)
    {
        Movie memory movie = movies[_movieSerial];
        uint256 increment = (movie.baseValue * movie.timesViewed) / 10;
        uint256 calculatedValue = movie.baseValue + increment;
        return calculatedValue;
    }

    // function to get ERC20 balance of "_address"
    function erc20Balance(address _address) public view returns (uint256) {
        return balanceOf(_address);
    }

    // Add new movie into the studio
    // @_length in seconds
    function AddMovie(
        string memory _name,
        string memory _description,
        uint256 _length,
        uint256 _value
    ) public onlyOwner {
        require(_length > 1 minutes, "Movie length too short");
        movies[serial] = Movie(
            serial,
            _name,
            _description,
            _length,
            5,
            1,
            0,
            _value,
            true
        );
        serial += 1;
    }

    // function to remove a movie from the cinema
    function removeMovie(uint256 _movieSerial) public onlyOwner {
        delete movies[_movieSerial];
    }

    // function to swap customer token for eth from contract
    function swapTokens(uint256 _quantity) public payable {
        require(_quantity > 0, "Invalid quantity of tokens entered");
        require(
            _quantity <= erc20Balance(msg.sender),
            "Quantity requested higher that your balance"
        );
        // first send token to contract
        _transfer(msg.sender, address(this), _quantity);
        // then get value of token in user wallet in return
        (bool success, ) = payable(msg.sender).call{
            value: (getValue(_quantity))
        }("");
        require(success, "Swap not successful");
    }

    // function to buy token from contract
    function buyToken(uint256 _quantity) public payable {
        uint256 cost = getValue(_quantity);
        require(
            msg.value >= cost,
            "Amount sent cannot purchase requested tokens"
        );
        uint256 contractTokenBalance = erc20Balance(address(this));
        // user cannot buy more than the token balance in the contract
        require(
            _quantity <= contractTokenBalance,
            "Insufficient tokens in contract"
        );
        // overflow is the balance remaining from excess amount user sends to contract
        uint256 overflow = msg.value - cost;
        // sends overflow amount back to user
        if (overflow > 0) payable(msg.sender).transfer(overflow);
        // transfer token to user
        _transfer(address(this), msg.sender, _quantity);
        // keep track of purchase
        users[msg.sender].tokensPurchased += _quantity;
    }

    // function to watch movie and pay tokens for it
    function seeMovie(uint256 _serial) public {
        // first confirm if movie is available
        require(movies[_serial].active, "Movie deleted/does not exist");
        // get calculated value of movie
        uint256 calculatedValue = calculateValue(_serial);
        // confirm if user has enough tokens to see movie
        require(
            calculatedValue <= erc20Balance(msg.sender),
            "You don't have enough tokens to see movie"
        );
        _transfer(msg.sender, address(this), calculatedValue);
        movies[_serial].timesViewed++;
        // Storage in the client's history of watched movies
        users[msg.sender].moviesViewed.push(movies[_serial].name);
    }

    // function to rate a movie, 1 and 5 inclusive
    function rateMovie(uint256 _serial, uint256 _rate) public {
        require((_rate > 0) && (_rate <= 5), "Invalid rate entered");
        require(!rated[_serial][msg.sender], "You can't rate movie more than once");
        movies[_serial].rates += _rate;
        movies[_serial].rateCount++;
        rated[_serial][msg.sender] = true;
    }


    // get details of movieuser has viewed
    function getMoviesViewed() public view returns (string[] memory) {
        return users[msg.sender].moviesViewed;
    }

    // function to get movie details
    function getMovieDetails(uint256 _serial)
        public
        view
        returns (
            string memory name,
            string memory description,
            uint256 length,
            uint256 timesViewed,
            uint256 rating,
            uint256 value
        )
    {
        require(movies[_serial].active, "Movie not active / movie deleted");
        Movie memory movie = movies[_serial];
        name = movie.name;
        description = movie.description;
        length = movie.length;
        timesViewed = movie.timesViewed;
        rating = movie.rates / movie.rateCount;
        value = calculateValue(movie.serialNo);
    }

    // function to withdraw funds from contract without "rug pulling" users funds
    function withdraw() public onlyOwner {
        // get total number of token users are hodling
        uint256 tokensOut = totalSupply() - erc20Balance(address(this));
        // amount in eth to pay token hodlers
        uint256 secureHodlers = address(this).balance - getValue(tokensOut);
        // balance owner will be able to withdraw such that there will be enough 
        // ethers in the contract for token holders
        uint256 organicBal = address(this).balance - secureHodlers;
        payable(owner()).transfer(organicBal);
    }
}
