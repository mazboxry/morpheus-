# スノードーム型ダイス攪拌システム 編集ガイドライン

## 1. 概要
本プロジェクトでは、サイコロを振る前の待機演出として**スノードーム（SnowDome）**と**中心引力（InvisibleBumper）**を用いた物理攪拌システムを採用しています。
スクリプトによる強制的な座標操作を行わず、Godotの3D物理エンジン（Jolt Physics）による自然な浮遊・バウンドを実現しています。

---

## 2. ノード構成 (`scenes/dice/dice_ball.tscn`)

```
DiceBall (Node3D, script = dice_ball.gd)
├── SnowDome (StaticBody3D)              # ダイスを閉じ込める反転球体
│   ├── MeshInstance3D (SphereMesh)      # 視覚用メッシュ (flip_faces = true)
│   └── CollisionShape3D (Concave...)    # 内側コリジョン (PhysicsMaterial: bounce=1.0, friction=0.0)
├── InvisibleBumper (Area3D)             # 中心へのポイントグラビティ
│   └── CollisionShape3D (SphereShape3D) # 重力適用エリア
├── PhysicalDie1 (RigidBody3D)          # ダイス1
├── PhysicalDie2 (RigidBody3D)          # ダイス2
├── PhysicalDie3 (RigidBody3D)          # ダイス3
└── PhysicalDie4 (RigidBody3D)          # ダイス4
```

---

## 3. 動作フロー

1. **待機状態（Ready / Staging）**:
   * `SnowDome` が表示・有効化 (`process_mode = PROCESS_MODE_INHERIT`) されています。
   * ダイス（RigidBody3D）は `InvisibleBumper` の負の中心引力（`gravity_point = true`）によってドーム中心に引き寄せられつつ、内壁（`bounce = 1.0`）で反射し、浮遊・攪拌し続けます。
2. **ロール開始 (`roll()`)**:
   * `SnowDome` が非表示・無効化 (`hide()` & `process_mode = PROCESS_MODE_DISABLED`) されます。
   * ドームの拘束から解放されたダイスが重力で下のフィールド／トレイへ落下し、物理的に停止します。

---

## 4. 人間による手動編集・調整ガイド

### A. スノードームの見た目・マテリアル調整（ガラス表現など）
* **場所**: `scenes/dice/dice_ball.tscn` -> `SnowDome/MeshInstance3D` -> `Material`
* **手順**:
  1. `MeshInstance3D` の `Material Override` に新規 `StandardMaterial3D` を作成。
  2. **Transparency（透明度）**: `Transparency Mode` を `Alpha` または `Alpha Hash` に設定し、`Albedo > Color` の Alpha 値（A）を `0.1` 〜 `0.3` 程度に下げる。
  3. **光沢・ハイライト**: `Roughness` を `0.05` 〜 `0.15`、`Metallic` を `0.1` 程度に設定。
  4. **屈折（Refraction）やリムライト（Rim）**: 必要に応じて `Rim` を有効にして輪郭を強調すると、ガラス球としての視認性が向上します。

### B. 攪拌の勢い・反発の調整
* **引力強度（集まりやすさ）**:
  * `InvisibleBumper` (Area3D) の `Gravity` パラメータ（デフォルト: `28.7` 前後）を増減します。
  * `Gravity Point Unit Distance` を調整すると、中心近くでの引力の減衰カーブを変更できます。
* **ドームの反発係数**:
  * `SnowDome` の `Physics Material Override` の `Bounce`（デフォルト: `1.0`）や `Friction`（デフォルト: `0.0`）で調整します。

### C. ドームの大きさや位置の調整
* `SnowDome` の Transform の Scale（現在 `3.6` 倍）や Position（Y=3.0）を Godot エディタで変更することで、ダイスの大きさに合わせたスケール調整が可能です。
* `InvisibleBumper` の Position も `SnowDome` の中心位置に合わせて一致させてください。

---

## 5. 注意点
* `SnowDome` のコリジョンメッシュは `flip_faces = true` の内向き法線である必要があります（外側コリジョンだとダイスが外に弾かれます）。
* ダイスのサイズや数を変更した場合は、ドーム内に初期配置したダイス同士が初期フレームで強くめり込まないよう、初期座標（`dice_ball.tscn` の Transform または `reset_dome()` の座標配列）を調整してください。
