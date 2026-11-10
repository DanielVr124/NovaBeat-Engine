# Building NovaBeat Engine

NovaBeat currently uses the official Friday Night Funkin' v0.8.6 source tree vendored under `upstream/Funkin/`. Its two required upstream asset repositories are pinned as Git submodules.

## Release and test build targets

- **Windows desktop:** release executable.
- **Android mobile:** debug APK, suitable for installation/testing after the user obtains the build output from an authorized private build environment.
- **HTML5 browser test:** experimental release-mode browser build, distributed privately for local browser testing. This is not yet a supported public release target; see [HTML5 browser testing](HTML5_TESTING.md).

Android's upstream v0.8.6 project configuration currently targets landscape orientation. A successful Android compile does not mean NovaBeat's separate portrait-and-landscape UI requirement is complete.

## Build cadence

Full platform compiles are intentionally **not** run for every small code change.

- Small changes and individual fixes are reviewed without launching the full Windows and Android toolchains.
- Run both platform builds after a requested feature set is implemented or a substantial batch of changes is ready.
- Run a full build before treating a milestone as build-verified.

The [NovaBeat platform build checks workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-platform-builds.yml) is opt-in. It runs when manually dispatched, when a relevant commit to `main` includes `[full-build]` in its commit message, or when a pull request title includes `[full-build]`. The separate [HTML5 browser test workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-html5.yml) runs when manually dispatched or when a relevant commit to `main` includes `[web-build]`. Both build workflows are kept separate so browser testing does not add time or failure points to Windows/Android builds.

## Private build downloads

Every successfully packaged Windows, Android, or HTML5 target is automatically published to a release in the private [NovaBeat-Builds repository](https://github.com/DanielVr124/NovaBeat-Builds), including pull-request builds. Each build job first uploads its package as a short-lived private Actions artifact; the separate `Publish NovaBeat build releases` workflow then collects the successful platform packages and creates the private release. This separation is required because GitHub does not expose repository secrets to pull-request build jobs. If one platform fails but another finishes packaging successfully, the successful platform is still published. Windows is packaged as `NovaBeat-Windows.zip`, Android as `NovaBeat-Android.apk`, and HTML5 as `NovaBeat-HTML5.zip`.

The first time this is configured, create a **fine-grained personal access token** on GitHub:

1. Open https://github.com/settings/personal-access-tokens/new.
2. Give it a name such as `NovaBeat private build uploader` and an expiry you are comfortable with.
3. Under **Repository access**, choose **Only select repositories** and select `DanielVr124/NovaBeat-Builds` only.
4. Under **Repository permissions**, grant **Contents: Read and write**. Metadata read access is included automatically.
5. Create the token, then immediately add it as an Actions secret in the public engine repository at https://github.com/DanielVr124/NovaBeat-Engine/settings/secrets/actions/new. Name the secret exactly `NOVABEAT_BUILDS_TOKEN` and paste the token as its value. Never put the token in source code or chat.

The token is used only by the separate release-publisher workflow after a build completes; it is never exposed to the Windows, Android, or HTML5 build jobs, including pull-request builds. It is scoped to the private delivery repository and cannot write to other repositories.

To build only Android without recompiling Windows, open the [platform build workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-platform-builds.yml), choose **Run workflow**, and select `android`. Choose `both` for a full milestone build. To build HTML5 independently, open the [HTML5 browser test workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-html5.yml) and choose **Run workflow**.

## Clone the repository

Use recursive submodule checkout so the exact pinned `assets` and `art` revisions are available:

```bash
git clone --recurse-submodules https://github.com/DanielVr124/NovaBeat-Engine.git
cd NovaBeat-Engine
```

For an existing clone:

```bash
git submodule update --init --recursive
```

## Common Haxe setup

Use **Haxe 4.3.7** and Git. From `upstream/Funkin/`, install the same patched Haxe library manager used by the upstream build setup:

```bash
haxelib fixrepo --global
haxelib --global install haxelib 4.1.0
haxelib --global set haxelib 4.1.0
haxelib --global remove haxelib git
haxelib --global remove hmm
haxelib --global git haxelib https://github.com/FunkinCrew/haxelib.git funkin-patches --skip-dependencies
haxelib --global git hmm https://github.com/FunkinCrew/hmm funkin-patches
haxelib --never newrepo
haxelib --global run hmm install -q
```

If either `remove` command reports that the library is not installed, it is safe to continue.

Compile the pinned HXCPP support tools before the platform build:

```bash
cd .haxelib/hxcpp/git/tools/hxcpp
haxe compile.hxml
cd ../../../../..
```

## Windows desktop

Install Visual Studio 2022 Build Tools with the **Desktop development with C++** workload, including MSVC v143 and a Windows 10/11 SDK.

From `upstream/Funkin/`, run:

```bash
haxelib run lime build windows -v -release -DGITHUB_BUILD
```

Expected output:

```text
export/release/windows/bin/Funkin.exe
```

## Android mobile

Install **JDK 17** and Android command-line tools. Install the exact SDK/NDK versions used by this source baseline:

```bash
sdkmanager --install \
  "platform-tools" \
  "platforms;android-29" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;29.0.13113456"
```

Set the Android toolchain paths before building:

- `ANDROID_HOME` and `ANDROID_SDK` to the Android SDK directory.
- `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT`, and `ANDROID_NDK` to its `ndk/29.0.13113456` directory.
- `JAVA_HOME` to the JDK 17 installation.

Then, from `upstream/Funkin/`, register the toolchain paths with Lime and build:

```bash
haxelib run lime config ANDROID_SDK "$ANDROID_HOME"
haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_HOME"
haxelib run lime config JAVA_HOME "$JAVA_HOME"
haxelib run lime config ANDROID_SETUP true
haxelib run lime build android -v -debug -DGITHUB_BUILD
```

The debug build does not need a release keystore. Lime writes the APK beneath the Android export directory under `export/`.

## HTML5 browser testing

The browser build is intentionally separate from the native platform workflow. It compiles with `haxelib run lime build html5 -v -release -DGITHUB_BUILD`, verifies that an HTML entry point and JavaScript bundle were generated, and publishes a ZIP only to the private NovaBeat-Builds repository. The complete manual test steps and current web limitations are documented in [HTML5_TESTING.md](HTML5_TESTING.md). Do not publish this build through public GitHub Pages or public Actions artifacts: the pinned upstream asset and art license files prohibit public redistribution of their content.

## Psych Engine compatibility

The current Psych package layouts, supported chart subset, script/runtime scope, limitations, and verification checklist are documented in [PSYCH_COMPATIBILITY.md](PSYCH_COMPATIBILITY.md). Native Windows builds are required to compile and test the filesystem-based Psych adapter; a green HTML5 build does not establish Psych mod compatibility.

The Psych compatibility adapter also includes the native Change Character event transaction; see [PSYCH_COMPATIBILITY.md](PSYCH_COMPATIBILITY.md) for the current supported event list and limitations. Story-menu back navigation now returns only to the original FNF main menu; no NovaBeat custom-menu state is referenced.

## What a green build means

A green Windows job means the v0.8.6 game source compiled into a Windows executable. A green Android job means the v0.8.6 game source compiled into an Android debug APK. A green HTML5 job means the game compiled into a browser bundle and the private ZIP was published. None of these results alone verifies runtime behavior on every PC, phone, or browser, and none completes NovaBeat's planned Mod Manager, gameplay extensions, or Android portrait/landscape adaptation.

