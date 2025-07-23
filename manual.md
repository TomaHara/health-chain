# HealthChain スマートコントラクト仕様書

## 概要

HealthChainは、医療データ管理システムのスマートコントラクトです。患者、医師、病院管理者間で医療記録の安全な管理とアクセス制御を行うことを目的としています。24KB制限に対応した軽量版として設計されています。

## アーキテクチャ

### ライセンス
- **ライセンス**: MIT License
- **Solidityバージョン**: ^0.8.0

## データ構造

### 列挙型（Enums）

#### Role
ユーザーの役割を定義します。
```solidity
enum Role { PATIENT, DOCTOR, HOSPITAL_ADMIN }
```
- `PATIENT (0)`: 患者
- `DOCTOR (1)`: 医師
- `HOSPITAL_ADMIN (2)`: 病院管理者

#### RecordType
医療記録の種類を定義します。
```solidity
enum RecordType { DIAGNOSIS, TREATMENT, EXAMINATION, SURGERY }
```
- `DIAGNOSIS (0)`: 診断
- `TREATMENT (1)`: 治療
- `EXAMINATION (2)`: 検査
- `SURGERY (3)`: 手術

### 構造体（Structs）

#### UserProfile
ユーザープロファイル情報を格納します。
```solidity
struct UserProfile {
    string name;        // ユーザー名
    Role role;          // ユーザーの役割
    address hospitalId; // 所属病院のアドレス（医師の場合）
    uint8 flags;        // ステータスフラグ
}
```

**flagsの詳細**:
- ビット1 (0x01): `isVerified` - 認証済み
- ビット2 (0x02): `isActive` - アクティブ
- ビット3 (0x04): `isSuspended` - 停止中

#### MedicalRecord
医療記録の情報を格納します。
```solidity
struct MedicalRecord {
    address patientId;      // 患者のアドレス
    address doctorId;       // 医師のアドレス
    address hospitalId;     // 病院のアドレス
    string encryptedData;   // 暗号化された医療データ
    uint256 timestamp;      // 記録作成時刻
    RecordType recordType;  // 記録の種類
}
```

#### AccessPermission
アクセス許可情報を格納します。
```solidity
struct AccessPermission {
    address hospital;       // 許可された病院のアドレス
    uint256 grantedDate;   // 許可付与日
    uint256 expiryDate;    // 有効期限（0の場合は無期限）
    bool isActive;         // 許可が有効かどうか
}
```

## 状態変数

### マッピング

#### users
```solidity
mapping(address => UserProfile) public users;
```
各アドレスに対応するユーザープロファイル情報を格納します。

#### registered
```solidity
mapping(address => bool) public registered;
```
ユーザーが登録済みかどうかを追跡します。

#### records
```solidity
mapping(uint256 => MedicalRecord) public records;
```
医療記録IDに対応する医療記録を格納します。

#### patientRecords
```solidity
mapping(address => uint256[]) public patientRecords;
```
各患者が持つ医療記録IDの配列を格納します。

#### permissions
```solidity
mapping(address => mapping(address => AccessPermission)) public permissions;
```
患者から病院へのアクセス許可情報を格納します。
- 第1キー: 患者のアドレス
- 第2キー: 病院のアドレス

#### hospitalDoctors
```solidity
mapping(address => address[]) public hospitalDoctors;
```
各病院に所属する医師のアドレス配列を格納します。

### 単純変数

#### nextId
```solidity
uint256 public nextId = 1;
```
次に作成される医療記録のIDを管理します。

#### admin
```solidity
address public admin;
```
システム管理者のアドレスです。

#### active
```solidity
bool public active = true;
```
システム全体のアクティブ状態を管理します。

## イベント

### UserReg
```solidity
event UserReg(address indexed user, Role role);
```
ユーザー登録時に発生します。

### RecordAdd
```solidity
event RecordAdd(uint256 indexed id, address indexed patient, address indexed doctor);
```
医療記録追加時に発生します。

### AccessGrant
```solidity
event AccessGrant(address indexed patient, address indexed hospital);
```
アクセス許可付与時に発生します。

### AccessRevoke
```solidity
event AccessRevoke(address indexed patient, address indexed hospital);
```
アクセス許可取り消し時に発生します。

## 修飾子（Modifiers）

### onlyPatient
```solidity
modifier onlyPatient()
```
患者のみが実行可能な関数に使用します。
- ユーザーの役割が`PATIENT`である
- アクティブフラグが立っている（flags & 2 > 0）

### onlyDoctor
```solidity
modifier onlyDoctor()
```
医師のみが実行可能な関数に使用します。
- ユーザーの役割が`DOCTOR`である
- 認証済みかつアクティブ（flags & 3 == 3）
- 停止されていない（flags & 4 == 0）

### onlyHospital
```solidity
modifier onlyHospital()
```
病院管理者のみが実行可能な関数に使用します。
- ユーザーの役割が`HOSPITAL_ADMIN`である
- アクティブフラグが立っている

### onlyAdmin
```solidity
modifier onlyAdmin()
```
システム管理者のみが実行可能な関数に使用します。

### isActive
```solidity
modifier isActive()
```
システムがアクティブな状態でのみ実行可能な関数に使用します。

## 関数詳細

### システム管理

#### toggleSystem()
```solidity
function toggleSystem() external onlyAdmin
```
システムのアクティブ状態を切り替えます。管理者のみ実行可能です。

#### setAdmin(address newAdmin)
```solidity
function setAdmin(address newAdmin) external onlyAdmin
```
新しい管理者を設定します。現在の管理者のみ実行可能です。

### ユーザー登録

#### regPatient(string memory name)
```solidity
function regPatient(string memory name) external isActive
```
患者として登録します。
- **引数**: `name` - ユーザー名
- **条件**: 未登録のアドレス、システムがアクティブ
- **設定フラグ**: 3 (verified + active)

#### regDoctor(string memory name, address hospital)
```solidity
function regDoctor(string memory name, address hospital) external isActive
```
医師として登録します。
- **引数**: 
  - `name` - ユーザー名
  - `hospital` - 所属病院のアドレス
- **条件**: 未登録のアドレス、指定病院が存在、システムがアクティブ
- **設定フラグ**: 2 (active only)

#### regHospital(string memory name)
```solidity
function regHospital(string memory name) external isActive
```
病院管理者として登録します。
- **引数**: `name` - 病院名
- **条件**: 未登録のアドレス、システムがアクティブ
- **設定フラグ**: 3 (verified + active)

### 病院管理

#### addDoctor(address doctor)
```solidity
function addDoctor(address doctor) external onlyHospital
```
医師を病院に追加し、認証済みステータスを付与します。
- **引数**: `doctor` - 医師のアドレス
- **条件**: 呼び出し者が病院管理者、指定医師が同じ病院に所属

#### suspendDoctor(address doctor)
```solidity
function suspendDoctor(address doctor) external onlyHospital
```
医師を停止状態にします。
- **引数**: `doctor` - 医師のアドレス
- **条件**: 指定医師が同じ病院に所属

#### unsuspendDoctor(address doctor)
```solidity
function unsuspendDoctor(address doctor) external onlyHospital
```
医師の停止状態を解除します。
- **引数**: `doctor` - 医師のアドレス
- **条件**: 指定医師が同じ病院に所属

### アクセス管理

#### grantAccess(address hospital, uint256 expiry)
```solidity
function grantAccess(address hospital, uint256 expiry) external onlyPatient isActive
```
病院に対してアクセス許可を付与します。
- **引数**:
  - `hospital` - 病院のアドレス
  - `expiry` - 有効期限（0の場合は無期限）
- **条件**: 呼び出し者が患者、指定アドレスが病院管理者、有効期限が未来日時

#### revokeAccess(address hospital)
```solidity
function revokeAccess(address hospital) external onlyPatient
```
病院に対するアクセス許可を取り消します。
- **引数**: `hospital` - 病院のアドレス

#### hasAccess(address patient, address hospital)
```solidity
function hasAccess(address patient, address hospital) public view returns (bool)
```
病院が患者データにアクセス可能かチェックします。
- **引数**:
  - `patient` - 患者のアドレス
  - `hospital` - 病院のアドレス
- **戻り値**: アクセス可能な場合true

### 医療記録管理

#### addRecord(address patient, string memory data, RecordType rType)
```solidity
function addRecord(address patient, string memory data, RecordType rType) external onlyDoctor isActive returns (uint256)
```
新しい医療記録を追加します。
- **引数**:
  - `patient` - 患者のアドレス
  - `data` - 暗号化された医療データ
  - `rType` - 記録の種類
- **戻り値**: 新しい記録のID
- **条件**: 呼び出し者が医師、患者が存在、病院にアクセス許可あり

#### updateRecord(uint256 id, string memory newData)
```solidity
function updateRecord(uint256 id, string memory newData) external onlyDoctor
```
既存の医療記録を更新します。
- **引数**:
  - `id` - 記録ID
  - `newData` - 新しい暗号化データ
- **条件**: 呼び出し者が記録の作成医師

#### getRecord(uint256 id)
```solidity
function getRecord(uint256 id) external view returns (MedicalRecord memory)
```
医療記録を取得します。
- **引数**: `id` - 記録ID
- **戻り値**: 医療記録
- **条件**: 患者本人または許可された医師のみ

#### getPatientRecords(address patient)
```solidity
function getPatientRecords(address patient) external view returns (uint256[] memory)
```
患者の全医療記録IDを取得します。
- **引数**: `patient` - 患者のアドレス
- **戻り値**: 記録IDの配列
- **条件**: 患者本人または許可された医師のみ

#### getMyRecords()
```solidity
function getMyRecords() external view returns (uint256[] memory)
```
呼び出し者（患者）の医療記録IDを取得します。
- **戻り値**: 記録IDの配列
- **条件**: 呼び出し者が患者

### 情報取得関数

#### getProfile(address user)
```solidity
function getProfile(address user) external view returns (UserProfile memory)
```
ユーザープロファイルを取得します。

#### getHospitalDoctors(address hospital)
```solidity
function getHospitalDoctors(address hospital) external view returns (address[] memory)
```
病院所属の医師リストを取得します。

#### getHospitalStats(address hospital)
```solidity
function getHospitalStats(address hospital) external view returns (uint256 totalDocs, uint256 totalRecs)
```
病院の統計情報を取得します。
- **戻り値**:
  - `totalDocs` - 所属医師数
  - `totalRecs` - 総記録数

#### ステータス確認関数

以下の関数でユーザーのステータスを確認できます：
- `isVerified(address user)` - 認証済みかどうか
- `isActiveUser(address user)` - アクティブかどうか  
- `isSuspended(address user)` - 停止中かどうか

## 使用フロー

### 1. 初期設定
1. コントラクトをデプロイ（デプロイ者が管理者になる）
2. 病院管理者が`regHospital()`で登録
3. 医師が`regDoctor()`で登録（病院指定必要）
4. 病院管理者が`addDoctor()`で医師を認証
5. 患者が`regPatient()`で登録

### 2. 医療記録の管理
1. 患者が`grantAccess()`で病院にアクセス許可
2. 医師が`addRecord()`で医療記録を追加
3. 必要に応じて`updateRecord()`で記録を更新
4. 患者や医師が`getRecord()`で記録を閲覧

### 3. アクセス制御
1. 患者が必要に応じて`revokeAccess()`で許可を取り消し
2. 病院管理者が問題のある医師を`suspendDoctor()`で停止

## セキュリティ考慮事項

### アクセス制御
- 各機能は適切な修飾子で保護されている
- 患者データへのアクセスは明示的な許可が必要
- 医師は所属病院でのみ活動可能

### データ保護
- 医療データは暗号化されて保存される想定
- オンチェーンデータは最小限に抑制

### 権限管理
- 3段階の権限システム（患者、医師、病院管理者）
- フラグベースのステータス管理
- 管理者による緊急停止機能

## Remix Ethereum IDEでの実行とデバッグ

### 環境設定

#### 1. Remixでのファイル作成
1. Remix IDE（https://remix.ethereum.org/）にアクセス
2. `contracts`フォルダに`HealthChain.sol`を作成
3. 提供されたコードをコピー＆ペースト

#### 2. コンパイル設定
- **Compiler Version**: 0.8.0以上を選択
- **EVM Version**: デフォルト（london）
- **Optimization**: 有効（200回）
- **License**: MIT

### デプロイ手順

#### 1. Deploy & Run画面での設定
- **Environment**: JavaScript VM（テスト用）または Injected Web3（MetaMask使用）
- **Account**: デプロイ用アカウントを選択（管理者になる）
- **Gas Limit**: 3000000（十分な値を設定）
- **Value**: 0 ETH

#### 2. コントラクトのデプロイ
1. `HealthChain`を選択
2. `Deploy`ボタンをクリック
3. デプロイ成功後、`Deployed Contracts`セクションに表示

### Remixでのテスト手順

#### ステップ1: 管理者として初期設定確認
```javascript
// Deployed Contractsセクションで確認
admin() // デプロイしたアカウントのアドレスが返る
active() // true が返る
nextId() // 1 が返る
```

#### ステップ2: 病院管理者の登録
```javascript
// 新しいアカウントに切り替えて実行
regHospital("Tokyo General Hospital")

// 登録確認
registered(hospitalAddress) // true
getProfile(hospitalAddress) // name, role=2, flags=3 を確認
```

#### ステップ3: 医師の登録
```javascript
// 別のアカウントに切り替え
regDoctor("Dr. Tanaka", hospitalAddress)

// 病院管理者アカウントに戻って医師を認証
addDoctor(doctorAddress)

// 確認
getProfile(doctorAddress) // role=1, flags=3, hospitalId確認
isVerified(doctorAddress) // true
```

#### ステップ4: 患者の登録
```javascript
// 新しいアカウントで患者登録
regPatient("Patient Yamada")

// 確認
getProfile(patientAddress) // role=0, flags=3
```

#### ステップ5: アクセス許可の付与
```javascript
// 患者アカウントで実行
grantAccess(hospitalAddress, 0) // 0は無期限

// 確認
hasAccess(patientAddress, hospitalAddress) // true
```

#### ステップ6: 医療記録の追加
```javascript
// 医師アカウントで実行
addRecord(patientAddress, "encrypted_diagnosis_data", 0) // 0=DIAGNOSIS

// 確認
getMyRecords() // 患者アカウントで実行、[1]が返る
getRecord(1) // 医療記録の詳細確認
```

### 一般的なエラーパターンとRemixでのデバッグ

#### 1. 登録関連エラー
**エラー**: `execution reverted`
**原因**: 既に登録済みのアドレスで再登録しようとした

**デバッグ方法**:
```javascript
// Remixのコンソールで確認
registered("0x...") // 対象アドレスの登録状態確認
```

#### 2. 権限エラー
**エラー**: `execution reverted`  
**原因**: 適切な権限がないアカウントで関数を実行

**デバッグ方法**:
```javascript
// 現在のアカウントの情報確認
getProfile("0x...") // role と flags を確認
isVerified("0x...") // 認証状態確認
isActiveUser("0x...") // アクティブ状態確認
isSuspended("0x...") // 停止状態確認
```

#### 3. アクセス許可エラー
**エラー**: `execution reverted`
**原因**: 患者からのアクセス許可がない

**デバッグ方法**:
```javascript
// アクセス許可状態確認
hasAccess(patientAddress, hospitalAddress)

// 許可詳細の確認（publicマッピングとして直接アクセス）
permissions(patientAddress, hospitalAddress)
```

#### 4. システム停止エラー
**エラー**: `execution reverted`
**原因**: システムが非アクティブ状態

**デバッグ方法**:
```javascript
active() // false の場合、管理者がシステムを停止している
// 管理者アカウントで toggleSystem() を実行して復旧
```

### Remixでの効率的なテスト方法

#### 1. アカウント管理
Remixの`Account`ドロップダウンを使用して、異なる役割のアカウントを素早く切り替え：
- **Account 0**: 管理者（デプロイアカウント）
- **Account 1**: 病院管理者
- **Account 2**: 医師
- **Account 3**: 患者

#### 2. バッチテスト用JavaScript
Remix IDEの`JavaScript VM`環境で、以下のようなテストスクリプトを作成：

```javascript
// Remixコンソールで実行可能なテストスクリプト
async function fullTest() {
    const accounts = await web3.eth.getAccounts();
    const admin = accounts[0];
    const hospital = accounts[1]; 
    const doctor = accounts[2];
    const patient = accounts[3];
    
    console.log("=== HealthChain Full Test ===");
    
    // 病院登録テスト
    await contract.methods.regHospital("Test Hospital").send({from: hospital});
    console.log("✓ Hospital registered");
    
    // 医師登録テスト  
    await contract.methods.regDoctor("Dr. Test", hospital).send({from: doctor});
    await contract.methods.addDoctor(doctor).send({from: hospital});
    console.log("✓ Doctor registered and verified");
    
    // 患者登録テスト
    await contract.methods.regPatient("Test Patient").send({from: patient});
    console.log("✓ Patient registered");
    
    // アクセス許可テスト
    await contract.methods.grantAccess(hospital, 0).send({from: patient});
    console.log("✓ Access granted");
    
    // 医療記録追加テスト
    const tx = await contract.methods.addRecord(patient, "test_data", 0).send({from: doctor});
    console.log("✓ Medical record added, ID:", tx.events.RecordAdd.returnValues.id);
    
    console.log("=== All tests passed ===");
}
```

#### 3. イベントの監視
Remixの`Logs`タブでイベントを確認：
- `UserReg`: ユーザー登録の成功確認
- `RecordAdd`: 医療記録追加の確認
- `AccessGrant/AccessRevoke`: アクセス許可の変更確認

#### 4. ガス使用量の確認
各関数実行後、Remix IDEの`Terminal`でガス使用量を確認：
```
status: true Transaction mined and execution succeed
transaction hash: 0x...
gas: 21000 used
```

### Remixでの高度なデバッグ技術

#### 1. ブレークポイントとステップ実行
Remixの`Debugger`機能を使用：
1. 失敗したトランザクションのハッシュをコピー
2. `Debugger`タブを開く
3. トランザクションハッシュを入力
4. ステップバイステップで実行を追跡

#### 2. ストレージの直接確認
```javascript
// Remix IDEのコンソールで実行
// ユーザー情報の確認
await web3.eth.getStorageAt(contractAddress, 0) // users mapping の基準位置

// より簡単な方法：public変数の直接呼び出し
await contract.methods.users(userAddress).call()
await contract.methods.registered(userAddress).call()
```

#### 3. カスタムテスト関数の追加
開発時に以下のテスト用関数をコントラクトに一時追加：

```solidity
// デバッグ用関数（本番では削除）
function debugUserFlags(address user) external view returns (uint8) {
    return users[user].flags;
}

function debugPermission(address patient, address hospital) 
    external view returns (bool, uint256, uint256) {
    AccessPermission memory p = permissions[patient][hospital];
    return (p.isActive, p.grantedDate, p.expiryDate);
}

function debugCurrentTime() external view returns (uint256) {
    return block.timestamp;
}
```

#### 4. エラーメッセージのカスタム化
デバッグ時により詳細なエラーメッセージを追加：

```solidity
// 元のコード
require(users[msg.sender].role == Role.PATIENT && (users[msg.sender].flags & 2) > 0);

// デバッグ用改良版
require(users[msg.sender].role == Role.PATIENT, "Not a patient");
require((users[msg.sender].flags & 2) > 0, "Patient not active");
require((users[msg.sender].flags & 4) == 0, "Patient suspended");
```

### Remixでのパフォーマンステスト

#### ガス効率の測定
```javascript
// 各操作のガス使用量測定
const gasUsage = {
    regPatient: 0,
    regDoctor: 0,
    addRecord: 0,
    grantAccess: 0
};

// 患者登録のガス測定
const receipt = await contract.methods.regPatient("Test").send({from: account});
gasUsage.regPatient = receipt.gasUsed;
console.log(`Patient registration gas: ${receipt.gasUsed}`);
```

#### 大量データテスト
```javascript
// 複数の医療記録を追加してパフォーマンステスト
async function massRecordTest(count) {
    console.log(`Adding ${count} records...`);
    const startTime = Date.now();
    
    for(let i = 0; i < count; i++) {
        await contract.methods.addRecord(
            patientAddress, 
            `test_data_${i}`, 
            i % 4  // RecordType rotation
        ).send({from: doctorAddress});
    }
    
    const endTime = Date.now();
    console.log(`Time taken: ${endTime - startTime}ms`);
    
    // 記録数確認
    const recordCount = await contract.methods.getRecordCount(patientAddress).call();
    console.log(`Total records: ${recordCount}`);
}
```

### Remixでのセキュリティテスト

#### 1. 権限昇格攻撃のテスト
```javascript
// 患者が医師の権限で記録追加を試行（失敗すべき）
try {
    await contract.methods.addRecord(patientAddress, "malicious_data", 0)
        .send({from: patientAddress});
    console.error("SECURITY ISSUE: Patient can add records!");
} catch(error) {
    console.log("✓ Security check passed: Patient cannot add records");
}
```

#### 2. アクセス制御のテスト  
```javascript
// 許可のない病院からのアクセステスト
try {
    await contract.methods.getPatientRecords(patientAddress)
        .call({from: unauthorizedHospitalAddress});
    console.error("SECURITY ISSUE: Unauthorized access allowed!");
} catch(error) {
    console.log("✓ Security check passed: Unauthorized access blocked");
}
```

#### 3. 時間ベースの攻撃テスト
```javascript
// 期限切れアクセス許可のテスト
const expiredTime = Math.floor(Date.now() / 1000) - 3600; // 1時間前
await contract.methods.grantAccess(hospitalAddress, expiredTime)
    .send({from: patientAddress});

// 期限切れ後のアクセステスト
const hasAccess = await contract.methods.hasAccess(patientAddress, hospitalAddress).call();
console.log(`Expired access should be false: ${hasAccess}`);
```

## Remixでのトラブルシューティング

### よくある問題と解決方法

#### 1. コンパイルエラー
**問題**: `ParserError: Expected ';' but got identifier`
**解決**: 
- セミコロンの欠落を確認
- 構文エラーをチェック  
- Solidityバージョンが0.8.0以上か確認

#### 2. デプロイエラー  
**問題**: `Gas estimation failed` または `out of gas`
**解決**:
- Gas Limitを5000000に増加
- Optimizationを有効にする
- 不要なコードを削除

#### 3. 関数実行エラー
**問題**: `execution reverted` without message
**解決**:
```javascript
// より詳細なエラー情報を取得
try {
    await contract.methods.functionName().call();
} catch(error) {
    console.log("Error details:", error);
    console.log("Error message:", error.message);
    console.log("Error data:", error.data);
}
```

#### 4. アカウント切り替えの問題
**問題**: 異なるアカウントでの操作が反映されない
**解決**:
- Remixの`Account`セレクタで正しいアドレスを選択
- MetaMaskを使用している場合、アカウント切り替えを確認
- `from`パラメータを明示的に指定

### Remixでの本番環境デプロイ準備

#### 1. テストネットでのテスト
```javascript
// Goerli Testnetでのデプロイ設定
Environment: Injected Web3
Network: Goerli Test Network  
Gas Price: 20 Gwei
Gas Limit: 3000000
```

#### 2. セキュリティチェックリスト
- [ ] 全ての修飾子が適切に機能する
- [ ] アクセス制御が正しく実装されている
- [ ] 整数オーバーフロー対策（Solidity 0.8+で自動対応）
- [ ] 再入攻撃対策（該当する関数なし）
- [ ] DoS攻撃対策（ガス制限考慮）

#### 3. 最終テストスクリプト
```javascript
// 包括的なテストスクリプト
async function comprehensiveTest() {
    console.log("=== Comprehensive HealthChain Test ===");
    
    const accounts = await web3.eth.getAccounts();
    const [admin, hospital, doctor, patient, attacker] = accounts;
    
    // 正常フローテスト
    await normalFlowTest(hospital, doctor, patient);
    
    // セキュリティテスト
    await securityTest(attacker, patient, hospital);
    
    // パフォーマンステスト
    await performanceTest(doctor, patient);
    
    // エラーハンドリングテスト
    await errorHandlingTest();
    
    console.log("=== All tests completed ===");
}

async function normalFlowTest(hospital, doctor, patient) {
    console.log("--- Normal Flow Test ---");
    
    // ユーザー登録
    await contract.methods.regHospital("Test Hospital").send({from: hospital});
    await contract.methods.regDoctor("Dr. Test", hospital).send({from: doctor});
    await contract.methods.regPatient("Test Patient").send({from: patient});
    
    // 医師認証
    await contract.methods.addDoctor(doctor).send({from: hospital});
    
    // アクセス許可
    await contract.methods.grantAccess(hospital, 0).send({from: patient});
    
    // 医療記録追加
    await contract.methods.addRecord(patient, "test_diagnosis", 0).send({from: doctor});
    
    console.log("✓ Normal flow completed successfully");
}

async function securityTest(attacker, patient, hospital) {
    console.log("--- Security Test ---");
    
    // 不正な医療記録追加の試行
    try {
        await contract.methods.addRecord(patient, "malicious_data", 0).send({from: attacker});
        console.error("❌ Security breach: Unauthorized record addition");
    } catch(error) {
        console.log("✓ Unauthorized record addition blocked");
    }
    
    // 不正なアクセス許可取り消しの試行
    try {
        await contract.methods.revokeAccess(hospital).send({from: attacker});
        console.error("❌ Security breach: Unauthorized access revocation");
    } catch(error) {
        console.log("✓ Unauthorized access revocation blocked");
    }
}

async function performanceTest(doctor, patient) {
    console.log("--- Performance Test ---");
    
    const startTime = Date.now();
    const recordCount = 10;
    
    for(let i = 0; i < recordCount; i++) {
        await contract.methods.addRecord(
            patient, 
            `performance_test_${i}`, 
            i % 4
        ).send({from: doctor});
    }
    
    const endTime = Date.now();
    const avgTime = (endTime - startTime) / recordCount;
    
    console.log(`✓ Added ${recordCount} records`);
    console.log(`✓ Average time per record: ${avgTime.toFixed(2)}ms`);
}

async function errorHandlingTest() {
    console.log("--- Error Handling Test ---");
    
    // システム停止テスト
    await contract.methods.toggleSystem().send({from: admin});
    
    try {
        await contract.methods.regPatient("Should Fail").send({from: accounts[5]});
        console.error("❌ System shutdown not working");
    } catch(error) {
        console.log("✓ System shutdown working correctly");
    }
    
    // システム復旧
    await contract.methods.toggleSystem().send({from: admin});
    console.log("✓ System reactivated");
}
```

### Remixでのプロダクション考慮事項

#### 1. ガス最適化
```solidity
// 最適化された版での変更例
struct OptimizedUserProfile {
    bytes32 name;      // string → bytes32 (固定長で効率的)
    uint8 roleAndFlags; // role と flags を統合
    address hospitalId;
}
```

#### 2. エラーハンドリングの改善
```solidity
// カスタムエラーの使用（Solidity 0.8.4+）
error UnauthorizedAccess(address caller, string required);
error InvalidInput(string field, string reason);
error SystemInactive();

// 使用例
if (!active) revert SystemInactive();
if (users[msg.sender].role != Role.PATIENT) {
    revert UnauthorizedAccess(msg.sender, "PATIENT");
}
```

#### 3. 監査とセキュリティ
- OpenZeppelinライブラリの使用を検討
- 外部監査の実施
- バグバウンティプログラムの開催

---

この仕様書は、HealthChainスマートコントラクトの詳細な技術文書として、開発者がシステムを理解し、適切に実装・運用するための包括的なガイドを提供します。