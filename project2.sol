// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract MyToken is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable {
    
    address public owner;

    bytes32 public root;

    uint premium_fee= 1 ether;
     
    uint public max_limit=0;
    uint public platform_limit=0;
    uint public users_limit=0;

    uint phase_number=0;

    bool not_paused=true;


    bool transferable=false;

    
    mapping(address=>bool)public fee_mapping;

    mapping(address=>premium_users)public premium_mapping;

    mapping(address=>normal_users)public normal_mapping;

    mapping(address=>admins)public admins_mapping;
    
    mapping(uint=>phases)public phase_mapping;
    
    mapping(uint=>bool)public phase_activation_mapping;

    
    // Define an event to be emitted when the phase is created
    event phase_created(uint phase_id, uint phase_limit, uint premium_batch_limit, uint normal_batch_limit);

    // Define an event to be emitted when the phase is activated
    event phase_activated(uint phase_id,uint phase_limit);

    // Define an event to be emitted when the phase is deactivated
    event phase_deactivated(uint phase_id,uint phase_remaning_limit);

    // Define an event to be emitted when the phase limit is changed
    event phase_limit_updated(uint phase_id, uint limit, uint premium_batch_limit);

    // Define an event to be emitted when the phase limit is of normal or premium user is changed
    event user_phase_limit_updated(address user, uint limit);

    // Define an event to be emitted when user is verified
    event user_allowed(address user);
    
    // Define an event to be emitted when user is unverified
    event user_unallowed(address user);
    
    // Define an event to be emitted when user pay the premium fee
    event fee_transferred(address owner, address user);
    
    // Define an event to be emitted when new premium user is added
    event premium_user_added(address user,uint limit);
    
    // Define an event to be emitted when new normal user is aded
    event normal_user_added(address user,uint limit);
    
    // Define an event to be emitted when new admin is added
    event admin_added(address admin);
    
    // Define an event to be emitted when nft is minted
    event nft_minted(address to, uint256 tokenId, string uri);
    
    // Define an event to be emitted when the nft is tranferred
    event nft_transferred(address from, address to, uint256 tokenId);


    struct normal_users{
        address users_adres;
        uint normal_limit;
        bool registered;
    }

    
    struct premium_users{
        address users_adres;
        uint premium_limit;
        bool registered;
        bool allowed;
    }

    struct phases{
        uint phase_limit;
        uint premium_limit;
        uint premium_batch_limit;
        uint normal_limit;
        uint normal_batch_limit;
        uint phase_number;
        bool phase_created;      
    }

    struct admins{
        address admin;
        uint admin_limit;
        bool registered;
    }

    struct nfts_bulk{
        uint id;
        string uri;
    }

    
    constructor(uint max, uint platform, bytes32 _root) ERC721("MyToken", "MTK") {
        owner=msg.sender;
        max_limit=max;
        root = _root;
        require(platform_limit<max,"platform limit should be less than total minting limit");
        platform_limit=platform;
        users_limit=max-platform;
    }

    modifier only_owner(){
        require(msg.sender==owner," only owner is able to use this function");
        _;
    }

    modifier NotPaused(){
        require(not_paused==true," this function is paused");
        _;
    }

    
    /**
    * @dev phase_creation is used to create a new phase for minting.
    * Requirements :
    *  - This function can only be called by the present land inspector.
    *   @ pragma phase  -  total minting limit for a phase. 
    *   @ pragma premium - premium minting limit per users
    *   @ pragma premium_batch - total minting limit of premium users
    *   @ pragma normal - normal minting limit per users
    *   @ pragma phase_id - phase number
    */
    

    function create_phase(uint phase, uint premium,  uint premium_batch, uint normal,uint phase_id)public only_owner NotPaused{
        require(phase_activation_mapping[phase_id-1] == false,"Phase is already running");
        require(phase_mapping[phase_id].phase_created == false," Phase already exist");
        require(phase<=users_limit," phase limit should be less than users minting limit");
        require(premium_batch<=phase," Total premium limit for this phase cannot be more than phase limit");
        require(premium<=premium_batch," premium limit per user cannot be more than total premium limit of phase");

        
        phase_mapping[phase_id].normal_batch_limit = phase - premium_batch;
        require(normal<=phase_mapping[phase_id].normal_batch_limit," normal limit per user cannot be more than total normal limit of phase");
        

        phase_mapping[phase_id].phase_limit=phase;
        phase_mapping[phase_id].premium_limit=premium;
        phase_mapping[phase_id].normal_limit=normal;
        phase_mapping[phase_id].premium_batch_limit=premium_batch;
        phase_mapping[phase_id].phase_number=phase_id;
        phase_mapping[phase_id].phase_created=true;

        emit phase_created(phase_id, phase, premium_batch, phase_mapping[phase_number].normal_batch_limit);
        
    }

    
    /**
    * @dev activate_phase is used to activate the phase created by owner of this contract.
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma id  -  phase number
    */
    

    function activate_phase(uint id)public only_owner NotPaused{
        require(phase_mapping[id].phase_created == true," Phase does not exist");
        require(phase_activation_mapping[id] == false," Phase cannot be activated again");
        phase_activation_mapping[id]=true;
        users_limit -= phase_mapping[id].phase_limit;
        phase_number = id;
        
        emit phase_activated(id,phase_mapping[id].phase_limit);
    }

    
    /**
    * @dev deactivate_phase is used to deactivate the phase activated by owner of this contract.
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma id  -  phase number
    */


    function deactivate_phase(uint id)public only_owner NotPaused{
        require(phase_activation_mapping[id]==true," Phase is not activated yet");
        phase_mapping[id].phase_created = false;
        phase_activation_mapping[id]=false;
        
        emit phase_deactivated(id,phase_mapping[id].phase_limit);
    }

    
    /**
    * @dev update_phase_limit is used to update the limit of current phase .
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma limit - updated minting limit 
    *   @ pragma premium_batch - updated limit of premium_batch
    */

    
    function update_phase_limit(uint limit,uint premium_batch)public only_owner NotPaused{
        
        require(phase_mapping[phase_number].phase_created == true," Phase does not exist");
        require(limit>premium_batch," Premium batch limit should be less than updated phase limit ");
        require(premium_batch>phase_mapping[phase_number].premium_limit," new premium batch limit should be more than premium user limit  ");
        
        phase_mapping[phase_number].premium_batch_limit = premium_batch;
        phase_mapping[phase_number].normal_batch_limit = limit-premium_batch;
        
        uint previous_limit = phase_mapping[phase_number].phase_limit;
        
        if(limit>phase_mapping[phase_number].phase_limit)
        {
            users_limit -= limit - previous_limit;
            phase_mapping[phase_number].phase_limit = limit; 
        }
        else
        {
            users_limit += previous_limit - limit;
            phase_mapping[phase_number].phase_limit = limit;
        }

        require(phase_mapping[phase_number].normal_batch_limit>=phase_mapping[phase_number].normal_limit," new phase limit of normal user should be mor then the normal user limit");
        require(phase_mapping[phase_number].premium_batch_limit>=phase_mapping[phase_number].premium_limit," new phase limit of premium user should be mor then the premium user limit");
        emit phase_limit_updated(phase_number, limit, premium_batch);
    }

    
    /**
    * @dev update_phase_limit_of_user is used to update the limit of users .
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma user  -  user address
    *   @ pragma limit - updated minting limit 
    *   @ pragma age - age
    *   @ pragma city - city
    */
    
   
    function update_phase_limit_of_user(address user, uint limit)public only_owner NotPaused{
        
        require(phase_mapping[phase_number].phase_created == true," Phase does not exist");
        require(premium_mapping[user].registered==true || normal_mapping[user].registered==true," User does not exist");

        
        if(premium_mapping[user].registered==true)
        {

            require(premium_mapping[user].premium_limit == 0," premium minting limit of user is not zero");
            require(limit<=phase_mapping[phase_number].premium_limit," new limit of user should be less than or equal to previous limit");
            require(limit<=phase_mapping[phase_number].premium_batch_limit," premium limit per user cannot be more than total premium limit of phase");
            require(premium_mapping[user].allowed==true," Premium user not verified yet");
            
            premium_mapping[user].premium_limit = limit;
            
        }
        else
        {
            
            require(normal_mapping[user].normal_limit == 0," normal minting limit of user is not zero");
            require(limit<=phase_mapping[phase_number].normal_batch_limit," normal limit per user cannot be more than total normal limit of phase");
            require(limit<=phase_mapping[phase_number].normal_limit," new limit of user should be less than or equal to previous limit");
            normal_mapping[user].normal_limit = phase_mapping[phase_number].normal_limit;
        }

        emit user_phase_limit_updated(user,limit);
    }

    
    /**
    * @dev add_users is used to add users as normal user.
    * Requirements :
    *  - This function is called by any new user.
    *   @ pragma users_adres  -  user address
    */


    function add_users(address users_adres)public NotPaused{
        
        require(phase_activation_mapping[phase_number] == true,"phase not activated yet");
        require(msg.sender==users_adres,"not the real user");
        require(users_adres!=owner," Owner can not register as a user");
        require(admins_mapping[users_adres].registered == false," this address belongs to admin");
        require(premium_mapping[users_adres].registered==false && normal_mapping[users_adres].registered==false, "this address belongs to another user");
        
        normal_users memory new_users = normal_users (users_adres,phase_mapping[phase_number].normal_limit,true);
        normal_mapping[users_adres] = new_users;

        emit normal_user_added(users_adres,phase_mapping[phase_number].normal_limit);
        //total_users_id++;    
    }

    
    /**
    * @dev add_admins is used to add admins .
    * Requirements :
    *  - This function is called when user is verified .
    *   @ pragma adm  -  admin address
    */
    

    function add_admins(address adm)public only_owner NotPaused{
        
        require(adm!=owner," Owner can not register as a admin");
        require(admins_mapping[adm].registered == false," Already added admin");
        require(premium_mapping[adm].registered==false || normal_mapping[adm].registered==false, "this address belongs to another user");
        admins memory _admin = admins(adm,platform_limit,true);
        admins_mapping[adm] = _admin;

        emit admin_added(adm);
    }


    /**
    * @dev allow_to_mint is used to allow the premium user to mint nfts.
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma user  -  address of user
    */
    

   
    function allow_to_mint(address user)public only_owner NotPaused{

        require(phase_activation_mapping[phase_number] == true," Phase is not activated yet ");
        require(premium_mapping[user].allowed==false,"Already allowed to mint");
        require(premium_mapping[user].registered==true,"Premium user does not exist");

      
        premium_mapping[user].allowed=true;
        
        emit user_allowed(user);
    }
    

    
    /**
    * @dev unallow_to_mint is used to unallow the premium user to mint nfts.
    * Requirements :
    *  - This function can only be called by the owner of this contract.
    *   @ pragma user  -  address of user
    */
    

   
    function unallow_to_mint(address user)public only_owner NotPaused{
        
        require(premium_mapping[user].allowed==true," User not alowed to mint nfts yet");
     
        premium_mapping[user].allowed=false;
        
        emit user_unallowed(user);
    }
    


    
    /**
    * @dev fee_transfer is used to transfer the the fee for premium minting account.
    * Requirements :
    *  - This function can only be called by person who is paying the fee .
    *   @ pragma _owner  -  address of woner of this contract
    *   @ pragma user - user address
    */
    

    function fee_transfer( address user )public payable NotPaused{

        require(user==msg.sender," Not the real User");
        require(msg.value==premium_fee,"premium fee is 1 ether");

        payable (owner).transfer(msg.value);
        fee_mapping[user]=true;
        for_premium(user);
        emit fee_transferred(owner, user);

    }

    
    /**
    * @dev for_premium is used to add permium users.
    * Requirements :
    *  - This function is called when fee is paid by user .
    *   @ pragma user  -  premium user address
    */
    

    function for_premium(address user)private NotPaused{

        require(fee_mapping[user] == true,"Premium fee is not paid yet");

        
        premium_users memory new_users = premium_users (user,phase_mapping[phase_number].premium_limit,true,false);
        premium_mapping[user] = new_users;
        
        delete normal_mapping[user];
        
        emit premium_user_added(user,phase_mapping[phase_number].premium_limit);
    }
    



    /**
    * @dev premium_safeMint is used to mint nfts by premium user.
    * Requirements :
    *  - This function can only be called by the registered user.
    *   @ pragma string memory uri  -   user add the uri of nfts
    *   @ pragma uint memory tokenId -  user add the id of nfts
    *   @ pragma address to - user address
    */

    
    function premium_safeMint(address to, uint256 tokenId, string memory uri)public NotPaused{
        
        require(msg.sender==to," Not the real user");
        require(premium_mapping[to].registered==true," premium user does not exist");
        require(phase_activation_mapping[phase_number]==true," phase is not activated yet");
        require(phase_mapping[phase_number].phase_limit>0," Phase limit reached");

        require(premium_mapping[to].allowed==true," Premium user not allowed to mint ");
        require(phase_mapping[phase_number].premium_batch_limit>0,"phase limit of premium users reached");
        require(premium_mapping[to].premium_limit>0," premium users limit reached");

        premium_mapping[to].premium_limit--;
        phase_mapping[phase_number].premium_batch_limit--;
        
        phase_mapping[phase_number].phase_limit--;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit nft_minted(to, tokenId, uri);

    }

    
    /**
    * @dev normal_safeMint is used to mint nfts by normal user.
    * Requirements :
    *  - This function can only be called by the registered user.
    *   @ pragma string memory uri  -   user add the uri of nfts
    *   @ pragma uint memory tokenId -  user add the id of nfts
    *   @ pragma address to - user address
    */


    function normal_safeMint(address to, uint256 tokenId, string memory uri,bytes32[] memory proof,bytes32 leaf)public NotPaused{
        
        require(normal_mapping[to].registered==true," normal user does not exist");
        require(phase_activation_mapping[phase_number]==true," phase is not activated yet");
        require(phase_mapping[phase_number].phase_limit>0," Phase limit reached");


        
        require(keccak256(abi.encodePacked(msg.sender)) == leaf ," not the real user");
        require(is_allowed(proof,leaf)," not the allowed address");
        require(phase_mapping[phase_number].normal_batch_limit>0," phase limit of normal users reached");
        require(normal_mapping[to].normal_limit>0," normal users limit reached");

        normal_mapping[to].normal_limit--;
        phase_mapping[phase_number].normal_batch_limit--;

        phase_mapping[phase_number].phase_limit--;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit nft_minted(to, tokenId, uri);
    }


    
    
    /**
    * @dev admin_minting is used to mint nfts by admin.
    * Requirements :
    *  - This function can only be called by the registered user.
    *   @ pragma string memory uri  -   admin add the uri of nfts
    *   @ pragma uint memory tokenId -  amdin add the id of nfts
    *   @ pragma address to - admin address
    */


    function admin_minting(address to, uint256 tokenId, string memory uri)public NotPaused{
        
        require(msg.sender==to," not the real admin");
        require(admins_mapping[to].registered==true, " admin does not exist");
        require(balanceOf(to)<platform_limit," Platform minting limit reached");

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        platform_limit--;
        admins_mapping[to].admin_limit--;
    }

    
    /**
    * @dev premium_bulk_minting is used to mint nfts in large amount by premium user.
    * Requirements :
    *  - This function can only be called by the registered user.
    *   @ pragma string[] memory uri  -  array where registered user add the uri of nfts
    *   @ pragma uint[] memory tokenId - array where registered user add the id of nfts
    *   @ pragma address to - user address
    */
    

    function premium_bulk_minting(string[] memory uri, uint[] memory tokenId,address to)public NotPaused{
        
        
        require(uri.length == tokenId.length," invalid length");
        require(msg.sender==to," Not the real user");
        require(premium_mapping[to].registered==true," not the premium user exist");
        require(phase_activation_mapping[phase_number]==true," phase is not activated yet");
        require(phase_mapping[phase_number].phase_limit>0," Phase limit reached");

        for(uint i =0; i<uri.length; i++)
        {
            require(premium_mapping[to].allowed==true," Premium user not allowed to mint");
            require(phase_mapping[phase_number].premium_batch_limit>0,"phase limit of premium users reached");
            require(premium_mapping[to].premium_limit>0," premium users limit reached");

            premium_mapping[to].premium_limit--;
            phase_mapping[phase_number].premium_batch_limit--;
             
            phase_mapping[phase_number].phase_limit--; 

            _safeMint(to,tokenId[i]);
            _setTokenURI(tokenId[i],uri[i]);
        }        
    }

    /**
    * @dev normal_bulk_minting is used to mint nfts in large amount by normal user.
    * Requirements :
    *  - This function can only be called by the registered user.
    *   @ pragma string[] memory uri  -  array where registered user add the uri of nfts
    *   @ pragma uint[] memory tokenId - array where registered user add the id of nfts
    *   @ pragma address to - user address
    */


    function normal_bulk_minting(string[] memory uri, uint[] memory tokenId,address to,bytes32[] memory proof,bytes32 leaf)public NotPaused{
        
        
        require(uri.length == tokenId.length," invalid length");
       
        require(normal_mapping[to].registered==true," User does not exist");
        require(phase_activation_mapping[phase_number]==true," phase is not activated yet");
        require(phase_mapping[phase_number].phase_limit>0," Phase limit reached");

        for(uint i =0; i<uri.length; i++)
        {
            require(is_allowed(proof,leaf)," not the allowed address");
            require(keccak256(abi.encodePacked(msg.sender)) == leaf ," not the real user");
            require(normal_mapping[to].normal_limit>0," normal users limit reached");
                
            require(phase_mapping[phase_number].normal_batch_limit>0,"phase limit of normal users reached");

            phase_mapping[phase_number].normal_batch_limit--;
            normal_mapping[to].normal_limit--;
                
            phase_mapping[phase_number].phase_limit--; 

            _safeMint(to,tokenId[i]);
            _setTokenURI(tokenId[i],uri[i]);
        }        
    }

    
    /**
    * @dev admin_bulk_minting is used to mint nfts in large amount by admin.
    * Requirements :
    *  - This function can only be called by the registered admin.
    *   @ pragma string[] memory uri  -  array where registered admin add the uri of nfts
    *   @ pragma uint[] memory tokenId - array where registered admin add the id of nfts
    *   @ pragma address to - admin address
    */
    

    function admin_bulk_minting(string[] memory uri, uint[] memory tokenId,address to)public NotPaused{
        
        require(to==msg.sender," not the real admin");
        require(uri.length == tokenId.length," invalid length");
        require(admins_mapping[to].registered == true,"admin does not exist");
        require(platform_limit > 0,"Platform minting limit reached");

        for(uint i=0; i < tokenId.length; i++)
        {
            _safeMint(to, tokenId[i]);
            _setTokenURI(tokenId[i], uri[i]);
            platform_limit--;
            admins_mapping[to].admin_limit--;

        }
    }

    
    /**
    * @dev _transfer is used to transfer the the nfts form on address to another.
    * Requirements :
    *  - This function can only be called by the owner of that nfts.
    *   @ pragma from  -  user address who want to transfer nfts
    *   @ pragma to - address where user want to transfer
    *   @ pragma id - this is the id of nft that is to be transferred
    *   @ pragma city - city
    */
    

    function _transfer(address from, address to, uint256 tokenId) internal override(ERC721){
        require(transferable==true," transfer functions are deactivated");
        require(premium_mapping[from].premium_limit<phase_mapping[phase_number].premium_limit || normal_mapping[from].normal_limit<phase_mapping[phase_number].normal_limit," user does not have nfts");
        require(msg.sender==from," only the real user is able to run this function");


        super._transfer(from,to,tokenId);
        emit nft_transferred(from, to, tokenId);
    }

    
    /**
    * @dev activate_transfer is used to make the _transfer function activate by changing the boo; value of transferable.
    * Requirements :
    *  - This function can only be called by the owner of this contract
    */
    

    function activate_transfer()public only_owner{
        require(transferable==false," transfer functions are already activated ");

        transferable=true;
    }

    
    /**
    * @dev update_metadata is used to update the uri of the nfts whose id is provided.
    * Requirements :
    *  - This function can be called by anyone but the data of nft will only be updated by the real owner.
    *   @ pragma nfts_bulk[]  -  it is an array and consist of two inputs 1st id of nfts 2nd uri of that nft
    */
    

    function update_metadata(nfts_bulk[] memory data)public NotPaused{
    require(premium_mapping[msg.sender].premium_limit<phase_mapping[phase_number].premium_limit || normal_mapping[msg.sender].normal_limit<phase_mapping[phase_number].normal_limit," user does not have nfts");
        
        for(uint i=0; i<data.length; i++)
        {

            if(ownerOf(data[i].id) == msg.sender)
            {

                _setTokenURI(data[i].id, data[i].uri);
            }
        }
    }

    
    /**
    * @dev get_nfts is used to get all the nfts present at a given address.
    * Requirements :
    *  - This function can only be called by the owner of that address.
    *   @ pragma user  -  address of user who has nfts
    */
    

    function get_nfts(address user)public view NotPaused returns(nfts_bulk[] memory ) {
       require(premium_mapping[user].premium_limit<phase_mapping[phase_number].premium_limit || normal_mapping[user].normal_limit<phase_mapping[phase_number].normal_limit," user does not have nfts");
         require(msg.sender == user," not the real user");

        nfts_bulk[] memory _nfts = new nfts_bulk[](balanceOf(user));

          for(uint i=0; i<balanceOf(user); i++)
          {
            uint token_id = tokenOfOwnerByIndex(user,i);
            string memory uri = tokenURI(token_id);
            _nfts[i] = nfts_bulk(token_id,uri);
          }
        return _nfts;  
    }


    function is_allowed(bytes32[] memory proof, bytes32 leaf)private NotPaused view returns(bool){
        return MerkleProof.verify(proof,root,leaf);
    }



    function pause() public only_owner {
        _pause();
        require(not_paused==true," the functions are already paused");
        not_paused=false;
    }



    function unpause() public only_owner {
        _unpause();
        require(not_paused==false," the functions are not paused");
        not_paused=true;
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }



    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}