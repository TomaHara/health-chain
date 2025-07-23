# HealthChain Solidity実装要件定義書

## 1. システム概要

**プロジェクト名**: HealthChain - 医療データ管理システム  
**目的**: ブロックチェーン技術を活用した安全で透明な医療データ管理・共有システム  
**実装言語**: Solidity (^0.8.0)  
**デプロイ環境**: Remix IDE での動作確認必須

## 2. データ構造要件

### 2.1 列挙型 (Enums)

```solidity
// ユーザーの役割定義
enum Role {
    PATIENT,        // 患者
    DOCTOR,         // 医師
    HOSPITAL_ADMIN  // 病院管理者
}

// 医療記録の種類
enum RecordType {
    DIAGNOSIS,      // 診断
    TREATMENT,      // 治療
    EXAMINATION,    // 検査
    SURGERY         // 手術
}
```

### 2.2 構造体 (Structs)

#### ユーザープロフィール
```solidity
struct UserProfile {
    string name;            // ユーザー名
    Role role;             // 役割
    address hospitalId;    // 所属病院アドレス（医師の場合）
    bool isVerified;       // 認証状態
    bool isActive;         // アクティブ状態
}
```

#### 医療記録
```solidity
struct MedicalRecord {
    uint256 recordId;      // 記録ID（自動採番）
    address patientId;     // 患者アドレス
    address doctorId;      // 担当医師アドレス
    address hospitalId;    // 病院アドレス
    string encryptedData;  // 暗号化された医療データ
    uint256 timestamp;     // 記録作成日時
    RecordType recordType; // 記録種別
    bool isActive;         // 記録の有効状態
}
```

#### アクセス許可
```solidity
struct AccessPermission {
    address authorizedHospital;  // 許可された病院
    uint256 grantedDate;        // 許可日時
    uint256 expiryDate;         // 有効期限（0は無期限）
    string purpose;             // アクセス目的
    bool isActive;              // 許可の有効状態
}
```

## 3. 状態変数要件

### 3.1 必須の状態変数

```solidity
// ユーザー管理
mapping(address => UserProfile) public users;
mapping(address => bool) public registeredUsers;

// 医療記録管理
mapping(uint256 => MedicalRecord) public medicalRecords;
mapping(address => uint256[]) public patientRecords;
uint256 public nextRecordId;

// アクセス許可管理
mapping(address => mapping(address => AccessPermission)) public accessPermissions;
mapping(address => address[]) public patientAuthorizedHospitals;

// 病院-医師管理
mapping(address => address[]) public hospitalDoctors;
mapping(address => bool) public suspendedDoctors;

// システム管理
address public systemAdmin;
bool public systemActive;
```

## 4. 修飾子 (Modifiers) 要件

### 4.1 基本権限制御

```solidity
modifier onlyPatient(address patientId) {
    require(msg.sender == patientId, "Only patient can perform this action");
    require(users[msg.sender].role == Role.PATIENT, "User is not a patient");
    require(users[msg.sender].isActive, "Patient account is not active");
    _;
}

modifier onlyDoctor() {
    require(users[msg.sender].role == Role.DOCTOR, "Only doctors allowed");
    require(users[msg.sender].isVerified, "Doctor not verified");
    require(users[msg.sender].isActive, "Doctor account not active");
    require(!suspendedDoctors[msg.sender], "Doctor is suspended");
    _;
}

modifier onlyHospitalAdmin() {
    require(users[msg.sender].role == Role.HOSPITAL_ADMIN, "Only hospital admin allowed");
    require(users[msg.sender].isActive, "Admin account not active");
    _;
}

modifier onlySystemAdmin() {
    require(msg.sender == systemAdmin, "Only system admin allowed");
    _;
}
```

### 4.2 複合権限制御

```solidity
modifier onlyAuthorizedForPatient(address patientId) {
    require(
        msg.sender == patientId || 
        hasHospitalAccess(patientId, users[msg.sender].hospitalId),
        "Not authorized to access patient data"
    );
    _;
}

modifier systemIsActive() {
    require(systemActive, "System is currently inactive");
    _;
}

modifier validAddress(address addr) {
    require(addr != address(0), "Invalid address");
    _;
}
```

## 5. イベント要件

### 5.1 ユーザー管理イベント
```solidity
event UserRegistered(address indexed user, Role role, string name);
event UserVerified(address indexed user, address indexed verifiedBy);
event UserSuspended(address indexed user, address indexed suspendedBy);
```

### 5.2 アクセス管理イベント
```solidity
event AccessGranted(
    address indexed patient, 
    address indexed hospital, 
    uint256 expiryDate, 
    string purpose
);
event AccessRevoked(address indexed patient, address indexed hospital, uint256 timestamp);
```

### 5.3 医療記録イベント
```solidity
event MedicalRecordAdded(
    uint256 indexed recordId, 
    address indexed patient, 
    address indexed doctor, 
    RecordType recordType
);
event MedicalRecordUpdated(uint256 indexed recordId, address indexed updatedBy);
```

### 5.4 病院管理イベント
```solidity
event DoctorAdded(address indexed doctor, address indexed hospital);
event DoctorSuspended(address indexed doctor, address indexed hospital);
```

## 6. 関数実装要件

### 6.1 初期化・システム管理

#### コンストラクタ
```solidity
constructor() {
    systemAdmin = msg.sender;
    systemActive = true;
    nextRecordId = 1;
}
```

#### システム管理機能
- `toggleSystemStatus()` - システムの有効/無効切り替え（システム管理者のみ）
- `transferSystemAdmin(address newAdmin)` - システム管理者権限移譲

### 6.2 ユーザー登録・管理機能

#### 患者用関数
```solidity
function registerPatient(string memory name) external
function updatePatientProfile(string memory newName) external onlyPatient(msg.sender)
```

#### 医師用関数  
```solidity
function registerDoctor(string memory name, address hospitalId) external
function updateDoctorProfile(string memory newName) external onlyDoctor()
```

#### 病院管理者用関数
```solidity
function registerHospitalAdmin(string memory name) external
function addDoctor(address doctor) external onlyHospitalAdmin()
function suspendDoctor(address doctor) external onlyHospitalAdmin()
function reactivateDoctor(address doctor) external onlyHospitalAdmin()
```

### 6.3 アクセス許可管理機能

#### 患者用アクセス管理
```solidity
function grantAccess(
    address hospital, 
    uint256 expiryDate, 
    string memory purpose
) external onlyPatient(msg.sender) validAddress(hospital)

function revokeAccess(address hospital) external onlyPatient(msg.sender)

function viewMyAccessPermissions() external view onlyPatient(msg.sender) 
    returns (address[] memory hospitals, AccessPermission[] memory permissions)
```

#### アクセス権限確認
```solidity
function hasHospitalAccess(address patient, address hospital) public view returns (bool)
function isAccessExpired(address patient, address hospital) public view returns (bool)
```

### 6.4 医療記録管理機能

#### 医療記録追加・更新
```solidity
function addMedicalRecord(
    address patient,
    string memory encryptedData,
    RecordType recordType
) external onlyDoctor() validAddress(patient) 
  returns (uint256 recordId)

function updateMedicalRecord(
    uint256 recordId,
    string memory newEncryptedData
) external onlyDoctor()
```

#### 医療記録閲覧
```solidity
function viewPatientRecords(address patient) external view 
    onlyAuthorizedForPatient(patient) 
    returns (MedicalRecord[] memory)

function viewMyRecords() external view onlyPatient(msg.sender) 
    returns (MedicalRecord[] memory)

function getRecordById(uint256 recordId) external view 
    returns (MedicalRecord memory)
```

### 6.5 統計・履歴機能

#### アクセス履歴
```solidity
function viewAccessLog(address patient) external view 
    returns (address[] memory accessors, uint256[] memory timestamps)
```

#### 病院統計
```solidity
function viewHospitalStatistics() external view onlyHospitalAdmin() 
    returns (
        uint256 totalDoctors,
        uint256 activeDoctors,
        uint256 totalRecords
    )
```

## 7. エラーハンドリング要件

### 7.1 カスタムエラー定義
```solidity
error UnauthorizedAccess(address caller, string action);
error InvalidRole(address user, Role expectedRole);
error ExpiredAccess(address patient, address hospital);
error RecordNotFound(uint256 recordId);
error UserNotRegistered(address user);
error SystemInactive();
```

### 7.2 必須のrequire文
- すべての外部関数で適切な権限チェック
- アドレスの有効性検証（address(0)チェック）
- システムの有効性確認
- データの存在確認
- 期限切れアクセスの検証

## 8. セキュリティ要件

### 8.1 アクセス制御
- 各機能に対する適切な修飾子の適用
- 患者データへのアクセスは明示的な許可が必要
- 病院管理者は所属医師のみ管理可能
- システム管理者機能の厳格な制限

### 8.2 データ保護
- 医療データの暗号化（外部で実装、ハッシュまたは暗号化文字列として保存）
- 記録の論理削除（物理削除禁止）
- アクセス期限の自動チェック

## 9. テスト要件

### 9.1 Remixでの動作確認項目

#### 基本機能テスト
1. 各役割のユーザー登録
2. 医師の病院への追加
3. 患者によるアクセス許可
4. 医療記録の追加・更新
5. アクセス権限の取り消し

#### セキュリティテスト
1. 権限のない操作の拒否確認
2. 期限切れアクセスの拒否確認
3. 停止された医師の操作拒否確認

#### エラーハンドリングテスト
1. 無効なアドレスでの操作
2. 存在しない記録へのアクセス
3. 重複登録の防止

## 10. デモンストレーション要件

### 10.1 デモシナリオ
1. **システム初期化**: 管理者設定
2. **ユーザー登録**: 患者、医師、病院管理者の登録
3. **権限設定**: 医師の病院への追加、認証
4. **アクセス許可**: 患者から病院へのアクセス許可
5. **医療記録操作**: 記録追加、更新、閲覧
6. **権限管理**: アクセス取り消し、医師停止
7. **監査機能**: アクセスログ、統計情報確認

### 10.2 デモビデオ要件
- 実行時間: 1-2分
- 主要機能の動作確認
- 権限制御の動作デモンストレーション
- エラーハンドリングの確認

## 11. 提出要件

### 11.1 成果物
1. **完全なSolidityソースコード**
   - 全機能実装済み
   - 適切なコメント付き
   - Remix での動作確認済み

2. **テスト実行ログ**
   - 各機能の動作確認結果
   - エラーケースの確認結果

3. **デモンストレーションビデオ**
   - 1-2分の動作デモ
   - 主要機能の使用例

4. **システム概要ドキュメント**
   - アーキテクチャ説明
   - 使用方法ガイド

### 11.2 品質基準
- コンパイルエラーなし
- 全修飾子が適切に動作
- 全イベントが適切に発火
- セキュリティホールなし
- ガス効率性の考慮

## 12. 実装優先順位

### Phase 1: コア機能
1. 基本的なデータ構造
2. ユーザー登録機能
3. 基本的な権限制御

### Phase 2: 主要機能
1. アクセス許可管理
2. 医療記録管理
3. 基本的な閲覧機能

### Phase 3: 管理機能
1. 病院管理機能
2. 統計・履歴機能
3. システム管理機能

### Phase 4: セキュリティ強化
1. 詳細なエラーハンドリング
2. セキュリティ検証
3. テスト・デバッグ

この要件定義に基づいて、段階的に実装を進めることで、確実に動作するHealthChainシステムを構築できます。