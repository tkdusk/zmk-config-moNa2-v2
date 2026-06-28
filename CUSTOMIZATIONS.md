# moNa2-v2 カスタマイズ一覧

upstream (`sayu-hub/zmk-config-moNa2-v2` dya-studio ブランチ) からの変更点を記録する。
将来のアップデート取り込み時に同じカスタマイズを再適用するためのリファレンス。

---

## 1. ビルド設定

### `.github/workflows/build.yml` ── 全面書き換え

**変更理由:** upstream は ZMK 公式 reusable workflow を使用。本 fork では以下が必要:
- ENTER_PASS_BINDINGS シークレット注入（パスワードマクロ）
- `zephyr/` ディレクトリ競合を避けるため west workspace を `/tmp/zmk-build` に分離
- カスタムモジュール (`zmk-input-processor-gestures`) の追加

**再現手順:**
```yaml
# upstream の build.yml を以下で完全に置き換える
# key points:
# 1. West Init を /tmp/zmk-build で実行（recursive Kconfig 回避）
# 2. Inject secret macros ステップを追加
# 3. ZMK_EXTRA_MODULES に ${GITHUB_WORKSPACE}/zmk-input-processor-gestures を追加
```
→ 現在の `.github/workflows/build.yml` をそのまま使用する

**必要な GitHub Secrets:**
- `ENTER_PASS_BINDINGS`: パスワードマクロのキーシーケンス（例: `&kp LS(A) &kp B &kp RET`）

---

### `build.yaml` ── ビルドマトリクス整理

**変更内容:**
- PAW3222 バリアント削除（PMW3610 のみ使用）
- USB ロギングビルド削除
- `artifact-name` を `mona2_r` / `mona2_l` に統一

**再現:** upstream の build.yaml から PAW3222・logging エントリを削除する

---

### `.gitignore` ── 新規追加

**変更内容:** ビルド成果物・ローカルスクリプトを除外

```gitignore
build/
*.uf2
*.bin
build-dya.sh
.DS_Store
```

---

## 2. トラックボール設定

### `boards/shields/mona2/mona2_r.overlay`

#### 2-1. PMW3610 センサー値（個体差・好み）

```diff
- cpi = <600>;
+ cpi = <800>;

- //invert-y;
+ invert-y;
```

#### 2-2. スクロールレイヤー変更

```diff
- active-layers = <0x000000C0>;  /* layer6 + layer7 */
+ active-layers = <0x00000008>;  /* layer3 (scroll layer) */
```

#### 2-3. マウス自動レイヤー (temp-layer)

```diff
 &mouse_runtime_input_processor {
-    /* 例: マウス感度初期値を Studio から調整したいだけならここで触らなくてOK */
+    temp-layer-enabled;
+    temp-layer = <4>;
+    temp-layer-deactivation-delay-ms = <500>;
 };
```

#### 2-4. ZMK Studio RPC UART（上流では snippet で設定、ここでは overlay に記述）

```devicetree
/ {
    chosen {
        zmk,studio-rpc-uart = &snippet_studio_rpc_usb_uart;
    };
};

&zephyr_udc0 {
    snippet_studio_rpc_usb_uart: snippet_studio_rpc_usb_uart {
        compatible = "zephyr,cdc-acm-uart";
    };
};
```

#### 2-5. ジェスチャー機能（★メインカスタマイズ）

入力プロセッサチェーンを更新:
```diff
- input-processors = <&mouse_runtime_input_processor &scroll_runtime_input_processor>;
+ input-processors = <&trackball_gestures &mouse_runtime_input_processor &scroll_runtime_input_processor>;
```

`trackball_gestures` ノードを追加:
```devicetree
/ {
    trackball_gestures: trackball_gestures {
        compatible = "zmk,input-processor-gestures";
        #input-processor-cells = <0>;
        bindings = <&kp LC(UP)>,
                   <&kp LC(DOWN)>,
                   <&kp LC(LEFT)>,
                   <&kp LC(RIGHT)>;
        threshold = <60>;      /* 調整可: 小さいほど敏感 */
        timeout-ms = <180>;
        cooldown-ms = <200>;
        tap-ms = <30>;
        active-layers = <0x00000020>; /* bit5 = layer 5 */
    };
};
```

---

## 3. キーマップ

### `config/mona2.keymap` ── 大幅変更

upstream はデフォルトレイアウトで異なるキー配置。本 fork は以下を独自実装:

#### 3-1. 基本設定の変更

```diff
-flavor = "balanced";          # &mt
+flavor = "tap-preferred";
+tapping-term-ms = <150>;

-flavor = "balanced";          # &lt
+flavor = "tap-preferred";
-quick-tap-ms = <200>;
+quick-tap-ms = <300>;
```

#### 3-2. define 追加

```c
#define MOUSE 4
#define GESTURE 5
#define SCROLL 6
```

#### 3-3. ジェスチャーレイヤー関連

コンボ追加（`.` + `/` でジェスチャーレイヤー ON/OFF）:
```devicetree
gesture_layer {
    bindings = <&mo GESTURE>;
    key-positions = <31 32>;   /* DOT=31, SLASH=32 */
    layers = <0>;
};
```

レイヤー追加（layer 5: gesture_layer, 全 `&trans`）

#### 3-4. enter_pass マクロ（シークレット注入）

```devicetree
enter_pass: enter_pass {
    compatible = "zmk,behavior-macro";
    #binding-cells = <0>;
    bindings = <&none>; // ENTER_PASS_PH   ← CI でここに実際のキーシーケンスが注入される
    label = "ENTER_PASS";
};
```

#### 3-5. キー配置・レイヤー構成

upstream とは全面的に異なる独自配置。再現は `config/mona2.keymap` をそのままコピー。

---

## 4. シークレット注入

### `scripts/inject_secrets.py` ── 新規追加

ビルド時に `// ENTER_PASS_PH` プレースホルダーを GitHub Secrets の値で置換するスクリプト。
テキストとして保存しないことでパスワードをリポジトリから排除する仕組み。

---

## 5. ジェスチャーモジュール

### `zmk-input-processor-gestures/` ── 新規追加（全ファイル）

pite1222/zmk の `zmk,input-processor-gestures` をスタンドアロンモジュールとしてポート。
スワイプ検出方式（threshold + timeout window）でジェスチャー方向を判定し、
`k_work_delayable` で安全にビヘイビアを起動する。

**主要な変更点（pite1222 オリジナルからの差分）:**
- `active-layers` プロパティ追加（特定レイヤーのみ有効化）
- `layer-id` + `positions` → `bindings` 直接指定（ZMK Studio の keymap 書き込みとの競合回避）
- ビヘイビア起動を `k_work_delayable` に委譲（インプットプロセッサコンテキストでのデッドロック回避）

---

## 6. west.yml 変更点

```diff
- # zettaface リモート削除（keybind モジュールを使わなくなったため）
- - name: zettaface
-   url-base: https://github.com/zettaface

- # zmk-input-processor-keybind 削除（ジェスチャーモジュールに移行）
- - name: zmk-input-processor-keybind
-   remote: zettaface
-   revision: main

# DYA モジュールのリビジョンを upstream の最新に更新
  - name: zmk-module-ble-management
-   revision: 851661c
+   revision: zmk-v0.3.0.0
  - name: zmk-module-settings-rpc
-   revision: ad1c995
+   revision: main
  - name: zmk-module-runtime-input-processor
-   revision: dbf92f7
+   revision: zmk-v0.3.0.0
  - name: zmk-behavior-runtime-sensor-rotate
-   revision: 3bbd992
+   revision: main
```

---

## upstream 更新時の再適用手順

```bash
# 1. upstream の最新を取得
git fetch upstream
git merge upstream/dya-studio --no-commit --no-ff

# 2. 競合が予想されるファイルをローカル版で解決
git checkout HEAD -- .github/workflows/build.yml
git checkout HEAD -- scripts/inject_secrets.py
git checkout HEAD -- .gitignore
git checkout HEAD -- config/mona2.keymap
git checkout HEAD -- zmk-input-processor-gestures/

# 3. overlay は upstream ベースにローカル値を上書き
#    以下の値を確認・修正:
#    - cpi = <800>
#    - invert-y; （有効）
#    - scroll active-layers = <0x00000008>
#    - mouse temp-layer 設定
#    - trackball_gestures ノード
#    - input-processors チェーン

# 4. west.yml は upstream を基本採用
#    ただし zettaface/keybind エントリが復活していたら削除

# 5. build.yaml は upstream を確認後、不要なビルドターゲット削除

# 6. コミット＆プッシュ
git add -A
git commit -m "merge: upstream/dya-studio update"
git push
```
