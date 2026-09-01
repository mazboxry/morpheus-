# `Game` グローバル API リファレンス

対象: `autoload/game.gd`（プロジェクトの Autoload 名: `Game`）
目的: 以後の実装で、**画面をまたぐゲーム進行**に必要な `Game` の公開契約を
この文書だけで確認・更新できるようにする。戦闘・出現・個別画面の内部状態は
ここに置かない。

## 使い方と責務

`Game` は常駐するグローバルの進行管理者である。各画面・マネージャーは状態を
直接書き換えず、下記の遷移 API を呼ぶ。画面表示側（ルートモーダル
ナビゲーター）は `root_modal_requested` を受け、指定されたシーンを表示する。

```c
// 擬似 C ヘッダ。GDScript では Game.<名前> として利用する。
extern Game Game;
```

## 型

```c
typedef enum GameState {
    BOOT,         // 起動直後の画面
    TITLE,        // タイトル
    CONFIG,       // 設定
    TUTORIAL,     // チュートリアル
    MAIN_GAME,    // ステージ対戦本体
    STAGE_CLEAR,  // 最終ステージ以外のクリア
    GAME_OVER,    // 敗北
    GAME_CLEAR    // 最終ステージのクリア
} GameState;
```

* グローバル状態はこの列挙だけで表す。確認ダイアログなどの入れ子画面は、
  `GameState` に追加せず、その画面を所有する側のローカル状態にする。
* `MAIN_GAME` 中のダイス、行軍、戦闘などの細かな進行も `Game` ではなく、
  メインゲームのローカル FSM が所有する。

## 公開プロパティ・定数

```c
GameState  Game.state;             // 現在のグローバル状態。初期値: BOOT
StringName Game.current_stage_id;  // 次回／現在のステージ識別子。初期値: "stage_001"

const Dictionary<GameState, String> Game.ROOT_MODAL_SCENES;
```

### `state`

* 読み取り用途を基本とする現在状態。
* 変更は `transition_to()` または各目的別 API 経由で行う。外部コードが代入しては
  ならない。代入では通知が発行されず、画面と状態が不整合になるため。

### `current_stage_id`

* `start_main_game(stage_id)` が開始対象として保存するステージ ID。
* 次の開始で同じステージを使う場合は、`start_main_game()` を引数なしで呼べる。
* ID の実在確認やステージ設定の読込みは、この API の責務ではない。受信側の
  ステージ／対戦側が扱う。

### `ROOT_MODAL_SCENES`

各 `GameState` と、対応するルート表示シーンの `res://` パスの対応表である。
ナビゲーターは `root_modal_requested` の `state` をキーにして参照する。

| 状態 | シーン |
| --- | --- |
| `BOOT` | `res://scenes/ui/boot_modal.tscn` |
| `TITLE` | `res://scenes/ui/title_modal.tscn` |
| `CONFIG` | `res://scenes/ui/config_modal.tscn` |
| `TUTORIAL` | `res://scenes/ui/tutorial_modal.tscn` |
| `MAIN_GAME` | `res://scenes/main_game.tscn` |
| `STAGE_CLEAR` | `res://scenes/ui/stage_clear_modal.tscn` |
| `GAME_OVER` | `res://scenes/ui/game_over_modal.tscn` |
| `GAME_CLEAR` | `res://scenes/ui/game_clear_modal.tscn` |

状態やルートシーンを追加・削除・変更したときは、この表、`GameState`、
`ROOT_MODAL_SCENES` を同じ変更で更新する。

## シグナル（通知）

```c
signal state_changed(GameState previous_state,
                     GameState current_state,
                     Dictionary payload);

signal root_modal_requested(GameState state, Dictionary payload);

signal stage_requested(StringName stage_id);

signal dice_roll_requested(void);
```

### `state_changed(previous_state, current_state, payload)`

状態値が更新されたことを通知する。分析、状態依存の初期化、テスト用の監視に使う。
`previous_state` は遷移前、`current_state` は遷移後の値である。自己遷移も通知される。

### `root_modal_requested(state, payload)`

ルート画面を表示する要求。`state` に対応するシーンは
`ROOT_MODAL_SCENES[state]` から得る。画面切替の主な購読先はこれである。

### `stage_requested(stage_id)`

開始するステージ ID の通知。`start_main_game()` 時に、`state_changed` より先に
発行される。ステージ読込み担当はこの ID を受け取る。

### `dice_roll_requested()`

ダイスロールの要求通知として予約されているシグナル。現時点の `Game` API からは
発行されない。新しい発行 API を追加して実装するまでは、購読側がこれだけを
ゲーム進行の根拠にしてはならない。

## 関数プロトタイプと契約

```c
void Game._ready(void);
void Game.transition_to(GameState next_state, Dictionary payload = {});
void Game.open_title(void);
void Game.open_config(void);
void Game.open_tutorial(void);
void Game.start_main_game(StringName stage_id = Game.current_stage_id);
void Game.finish_stage(bool is_final_stage);
void Game.lose_game(void);
```

### `_ready()`

```c
void Game._ready(void);
```

Autoload の準備完了時に `transition_to(BOOT)` を呼ぶ内部ライフサイクル関数。
初期の `BOOT` 表示要求も通常の遷移通知として発行される。外部から呼ばない。

### `transition_to()`

```c
void Game.transition_to(GameState next_state, Dictionary payload = {});
```

任意のグローバル状態へ遷移する低レベル API。実行順は必ず次のとおり。

1. 現在の `state` を `previous_state` として退避する。
2. `state` を `next_state` に更新する。
3. `state_changed(previous_state, next_state, payload)` を発行する。
4. `root_modal_requested(next_state, payload)` を発行する。

`payload` は遷移に付随する任意の追加情報。受信側と呼び出し側でキーと値の意味を
合意して使う。汎用的な画面遷移には空辞書を渡す。通常の画面操作では、意味を明確に
した目的別 API を優先する。

### `open_title()` / `open_config()` / `open_tutorial()`

```c
void Game.open_title(void);    // TITLE へ遷移
void Game.open_config(void);   // CONFIG へ遷移
void Game.open_tutorial(void); // TUTORIAL へ遷移
```

それぞれタイトル、設定、チュートリアルを開く。空の `payload` で遷移する。
各画面のボタン処理から、状態を直接代入せずに呼ぶ。

### `start_main_game()`

```c
void Game.start_main_game(StringName stage_id = Game.current_stage_id);
```

指定ステージの対戦を開始する。

* `current_stage_id = stage_id` として開始 ID を保存する。
* `stage_requested(stage_id)` を発行する。
* 続けて `MAIN_GAME` へ遷移し、遷移 `payload` として
  `{ "stage_id": stage_id }` を渡す。
* 購読側がステージを準備する場合、通知順を前提にする必要があるときは
  `stage_requested`、ルート画面生成時に ID が必要なときは `payload["stage_id"]` を
  使用する。

### `finish_stage()`

```c
void Game.finish_stage(bool is_final_stage);
```

ステージ勝利を報告する。`is_final_stage == false` なら `STAGE_CLEAR`、`true` なら
`GAME_CLEAR` へ遷移する。勝敗の判定や次ステージ ID の決定は呼び出し側の責務である。

### `lose_game()`

```c
void Game.lose_game(void);
```

敗北を報告し、`GAME_OVER` へ遷移する。戦闘の停止・結果集計・演出の完了確認は、
呼び出す対戦側で済ませてから呼ぶ。

## 実装を変更するときの更新規則

1. 外部から読めるプロパティ、シグナル、関数、`GameState` のいずれかを変更したら、
   この文書の対応する宣言と契約を同じコミットで更新する。
2. シグナルの引数、`payload` のキー、または発行順を変えたら、シグナル節と
   `transition_to()`／該当 API の節を更新する。
3. `Game` に戦闘ユニット、ダイス結果、モーダルスタック、音声、個別 UI の内部状態を
   追加しない。それらは専用のシーンまたはマネージャーが所有し、必要なら狭い
   シグナル／API で連携する。
