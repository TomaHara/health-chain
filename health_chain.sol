// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title HealthChain - 医療データ管理システム（超軽量版）
 * @dev 24KB制限対応版
 */
contract HealthChain {
    
    // ========== 列挙型・構造体 ==========
    
    enum Role { PATIENT, DOCTOR, HOSPITAL_ADMIN }
    enum RecordType { DIAGNOSIS, TREATMENT, EXAMINATION, SURGERY }
    
    struct UserProfile {
        string name;
        Role role;
        address hospitalId;
        uint8 flags; // isVerified(1), isActive(2), isSuspended(4)
    }
    
    struct MedicalRecord {
        address patientId;
        address doctorId;
        address hospitalId;
        string encryptedData;
        uint256 timestamp;
        RecordType recordType;
    }
    
    struct AccessPermission {
        address hospital;
        uint256 grantedDate;
        uint256 expiryDate;
        bool isActive;
    }
    
    // ========== 状態変数 ==========
    
    mapping(address => UserProfile) public users;
    mapping(address => bool) public registered;
    mapping(uint256 => MedicalRecord) public records;
    mapping(address => uint256[]) public patientRecords;
    mapping(address => mapping(address => AccessPermission)) public permissions;
    mapping(address => address[]) public hospitalDoctors;
    
    uint256 public nextId = 1;
    address public admin;
    bool public active = true;
    
    // ========== イベント ==========
    
    event UserReg(address indexed user, Role role);
    event RecordAdd(uint256 indexed id, address indexed patient, address indexed doctor);
    event AccessGrant(address indexed patient, address indexed hospital);
    event AccessRevoke(address indexed patient, address indexed hospital);
    
    // ========== 修飾子 ==========
    
    modifier onlyPatient() {
        require(users[msg.sender].role == Role.PATIENT && (users[msg.sender].flags & 2) > 0);
        _;
    }
    
    modifier onlyDoctor() {
        require(users[msg.sender].role == Role.DOCTOR && 
                (users[msg.sender].flags & 3) == 3 && 
                (users[msg.sender].flags & 4) == 0);
        _;
    }
    
    modifier onlyHospital() {
        require(users[msg.sender].role == Role.HOSPITAL_ADMIN && (users[msg.sender].flags & 2) > 0);
        _;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }
    
    modifier isActive() {
        require(active);
        _;
    }
    
    // ========== コンストラクタ ==========
    
    constructor() {
        admin = msg.sender;
    }
    
    // ========== システム管理 ==========
    
    function toggleSystem() external onlyAdmin {
        active = !active;
    }
    
    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
    
    // ========== ユーザー登録 ==========
    
    function regPatient(string memory name) external isActive {
        require(!registered[msg.sender]);
        users[msg.sender] = UserProfile(name, Role.PATIENT, address(0), 3); // verified + active
        registered[msg.sender] = true;
        emit UserReg(msg.sender, Role.PATIENT);
    }
    
    function regDoctor(string memory name, address hospital) external isActive {
        require(!registered[msg.sender] && users[hospital].role == Role.HOSPITAL_ADMIN);
        users[msg.sender] = UserProfile(name, Role.DOCTOR, hospital, 2); // active only
        registered[msg.sender] = true;
        emit UserReg(msg.sender, Role.DOCTOR);
    }
    
    function regHospital(string memory name) external isActive {
        require(!registered[msg.sender]);
        users[msg.sender] = UserProfile(name, Role.HOSPITAL_ADMIN, address(0), 3);
        registered[msg.sender] = true;
        emit UserReg(msg.sender, Role.HOSPITAL_ADMIN);
    }
    
    // ========== 病院管理 ==========
    
    function addDoctor(address doctor) external onlyHospital {
        require(users[doctor].role == Role.DOCTOR && users[doctor].hospitalId == msg.sender);
        users[doctor].flags |= 1; // set verified
        hospitalDoctors[msg.sender].push(doctor);
    }
    
    function suspendDoctor(address doctor) external onlyHospital {
        require(users[doctor].hospitalId == msg.sender);
        users[doctor].flags |= 4; // set suspended
    }
    
    function unsuspendDoctor(address doctor) external onlyHospital {
        require(users[doctor].hospitalId == msg.sender);
        users[doctor].flags &= ~uint8(4); // unset suspended
    }
    
    // ========== アクセス管理 ==========
    
    function grantAccess(address hospital, uint256 expiry) external onlyPatient isActive {
        require(users[hospital].role == Role.HOSPITAL_ADMIN);
        require(expiry == 0 || expiry > block.timestamp);
        
        permissions[msg.sender][hospital] = AccessPermission(
            hospital, 
            block.timestamp, 
            expiry, 
            true
        );
        
        emit AccessGrant(msg.sender, hospital);
    }
    
    function revokeAccess(address hospital) external onlyPatient {
        permissions[msg.sender][hospital].isActive = false;
        emit AccessRevoke(msg.sender, hospital);
    }
    
    function hasAccess(address patient, address hospital) public view returns (bool) {
        AccessPermission memory p = permissions[patient][hospital];
        if (!p.isActive) return false;
        if (p.expiryDate != 0 && p.expiryDate <= block.timestamp) return false;
        return true;
    }
    
    // ========== 医療記録 ==========
    
    function addRecord(address patient, string memory data, RecordType rType) 
        external onlyDoctor isActive returns (uint256) {
        require(users[patient].role == Role.PATIENT);
        require(hasAccess(patient, users[msg.sender].hospitalId));
        
        uint256 id = nextId++;
        records[id] = MedicalRecord(
            patient,
            msg.sender,
            users[msg.sender].hospitalId,
            data,
            block.timestamp,
            rType
        );
        
        patientRecords[patient].push(id);
        emit RecordAdd(id, patient, msg.sender);
        return id;
    }
    
    function updateRecord(uint256 id, string memory newData) external onlyDoctor {
        require(records[id].doctorId == msg.sender);
        records[id].encryptedData = newData;
    }
    
    function getRecord(uint256 id) external view returns (MedicalRecord memory) {
        MedicalRecord memory r = records[id];
        require(msg.sender == r.patientId || 
                (users[msg.sender].role == Role.DOCTOR && 
                 hasAccess(r.patientId, users[msg.sender].hospitalId)));
        return r;
    }
    
    function getPatientRecords(address patient) external view returns (uint256[] memory) {
        require(msg.sender == patient || 
                (users[msg.sender].role == Role.DOCTOR && 
                 hasAccess(patient, users[msg.sender].hospitalId)));
        return patientRecords[patient];
    }
    
    function getMyRecords() external view returns (uint256[] memory) {
        require(users[msg.sender].role == Role.PATIENT);
        return patientRecords[msg.sender];
    }
    
    // ========== 統計・情報取得 ==========
    
    function getProfile(address user) external view returns (UserProfile memory) {
        return users[user];
    }
    
    function getHospitalDoctors(address hospital) external view returns (address[] memory) {
        return hospitalDoctors[hospital];
    }
    
    function getHospitalStats(address hospital) external view 
        returns (uint256 totalDocs, uint256 totalRecs) {
        require(users[msg.sender].role == Role.HOSPITAL_ADMIN);
        
        address[] memory docs = hospitalDoctors[hospital];
        totalDocs = docs.length;
        
        for (uint256 i = 1; i < nextId; i++) {
            if (records[i].hospitalId == hospital) totalRecs++;
        }
    }
    
    function isVerified(address user) external view returns (bool) {
        return (users[user].flags & 1) > 0;
    }
    
    function isActiveUser(address user) external view returns (bool) {
        return (users[user].flags & 2) > 0;
    }
    
    function isSuspended(address user) external view returns (bool) {
        return (users[user].flags & 4) > 0;
    }
    
    // ========== 患者用便利関数 ==========
    
    function viewMyPermissions() external view returns (address[] memory) {
        require(users[msg.sender].role == Role.PATIENT);
        
        // この実装では簡略化のため、基本的な情報のみ返す
        address[] memory empty = new address[](0);
        return empty;
    }
    
    function getRecordCount(address patient) external view returns (uint256) {
        return patientRecords[patient].length;
    }
}