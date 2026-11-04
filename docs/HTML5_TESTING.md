# NovaBeat HTML5 browser testing

NovaBeat has a separate, experimental HTML5 build workflow for testing the actual game in a desktop browser. It does not replace or modify the Windows and Android build workflows, and it is not yet a supported public release target.

## Run the HTML5 build

Open the [NovaBeat HTML5 browser test workflow](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-html5.yml) and choose **Run workflow**.

The workflow can also be triggered by a commit to `main` that changes the game source or web workflow and includes `[web-build]` in its commit message. It compiles the game with:

```bash
haxelib run lime build html5 -v -release -DGITHUB_BUILD
```

The workflow checks for the generated HTML entry point and JavaScript bundle, then uploads the complete browser package for the release publisher. When packaging succeeds, the separate publisher automatically adds `NovaBeat-HTML5.zip` to a release in the private [NovaBeat-Builds repository](https://github.com/DanielVr124/NovaBeat-Builds).

## Open the build in Chrome

1. Open the private NovaBeat-Builds release linked in the completed workflow summary.
2. Download `NovaBeat-HTML5.zip` and extract the entire archive into a folder.
3. Open PowerShell in that extracted folder.
4. Run `py -m http.server 8000`.
5. Visit [http://localhost:8000](http://localhost:8000) in Chrome.

Keep the PowerShell window open while testing. Press **Ctrl+C** to stop the server. On macOS or Linux, use `python3 -m http.server 8000` instead.

Do not double-click `index.html` from File Explorer. Browsers restrict some asset and audio behavior when a game is loaded directly from a `file://` URL; use the local HTTP server.

## Private distribution and licensing

The workflow intentionally does not publish a public website or a public Actions artifact. The upstream FNF assets and art are separately licensed proprietary content whose license files prohibit public redistribution. The compiled package therefore goes only to the private NovaBeat-Builds repository.

The separate release-publisher workflow uses the existing `NOVABEAT_BUILDS_TOKEN` Actions secret. The build workflow itself never receives this secret. It must be a fine-grained token with **Contents: Read and write** permission on `DanielVr124/NovaBeat-Builds`. See [Building NovaBeat](BUILDING.md#private-build-downloads) for setup details.

A live hosted test URL would require an authenticated/private static hosting destination. Do not switch this workflow to public GitHub Pages or publish its ZIP as a public artifact.

## Browser limitations

This is an experimental compatibility build. A successful compile proves that the source compiles for HTML5; it does not prove that every game feature works in every browser. The upstream project currently disables its debug menu, chart editor, animation editor, and stage editor on web builds. Browser audio requires an initial user interaction, and features depending on native desktop APIs may be unavailable.
