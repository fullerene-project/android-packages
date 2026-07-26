> [!CAUTION]
> **Free and Open-Source Android is under threat.**
>
> Google will turn Android into a locked-down platform, restricting your essential freedom to install apps of your choice. Make your voice heard.
>
> [**Keep Android Open**](https://keepandroidopen.org/).

<div align="center">
  <img width=210 src="./brending/logo_black_background_thin_borders.svg" alt="Logo"/>
  
  <h1>Fullerene Android Packages</h1>
  <p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/fullerene-project/android-packages?style=for-the-badge&color=blue" alt="License: AGPL v3"></a>
</p>
</div>

Official Nix package repository for the [Fullerene](https://github.com/fullerene-project/code) build and delivery infrastructure. Contains Nix expressions and derivations required for Android application builds.

# Nix Application Package Requirements
For compatibility with the Fullerene system, Nix flakes and derivations must satisfy requirements regarding flake exports, package metadata, and build output (`$out`) directory structure.
## 1. Flake Structure
Packages must be exported in the Flake output under the `x86_64-linux` architecture path:
```
packages.x86_64-linux.<packageName>
```
## 2. Package Metadata (`passthru`)
The package derivation must expose metadata attributes via the `passthru` attribute set:

| `passthru` Attribute   | Type    | Description                                                             | Required |
| :--------------------- | :------ | :---------------------------------------------------------------------- | :------- |
| `androidApplicationId` | String  | Unique Android Application ID (e.g., `com.example.app`)                 | Yes      |
| `appName`              | String  | Full display name of the application                                    | Yes      |
| `appSummary`           | String  | Short summary of the application                                        | Yes      |
| `appDescription`       | String  | Detailed description of the application                                 | Yes      |
| `appLicense`           | String  | License identifier (e.g., `AGPL-3.0`)                                   | Yes      |
| `logoUrl`              | String  | Direct URL link to the application logo                                 | Yes      |
| `baseVersionCode`      | Integer | Numeric base version code                                               | Yes      |
| `appVersionString`     | String  | Version string representation (e.g., `1.0.0`)                           | Yes      |
| `releaseChannel`       | Integer | Release channel (see [Enumerations Reference](#enumerations-reference)) | Yes      |
| `appReleaseDate`       | String  | Release timestamp in ISO 8601 format                                    | Yes      |
| `nixPackageRevision`   | Integer | Nix package revision number                                             | Yes      |
| `releaseNotes`         | String  | Release notes / Changelog text                                          | Optional |
Nix Expression Example:
```nix
stdenv.mkDerivation {
  pname = "example-app";
  version = "1.0.0";

  # ... build logic ...

  passthru = {
    androidApplicationId = "org.example.app";
    appName = "Example App";
    appSummary = "Short summary of the app";
    appDescription = "Detailed description of the app";
    appLicense = "AGPL-3.0";
    logoUrl = "https://example.com/logo.png";
    baseVersionCode = 100;
    appVersionString = "1.0.0";
    releaseChannel = 10;
    appReleaseDate = "2026-07-25T00:00:00Z";
    nixPackageRevision = 1;
    releaseNotes = "Initial release";
  };
}
```
## 3. Build Output Requirements (`$out`)
Upon build completion, the derivation's output directory (`$out`) must contain:
1. Unsigned APK files (`*.apk`).
2. A build manifest file named `manifest.json`.
### `manifest.json` Schema
The file must be located at the root of `$out` and adhere to the following structure:
```json
{
  "releaseChannel": 10,
  "entries": [
    {
      "fileName": "app-universal-release-unsigned.apk",
      "fileSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "fileSizeBytes": 15420100,
      "artifactType": 1,
      "versionCode": 100,
      "minApiLevel": 21,
      "targetApiLevel": 34,
      "splitId": null,
      "moduleName": null,
      "cpuArchitectures": [3, 5],
      "singleCpuArchitecture": null,
      "densityAlias": null,
      "densityDpi": null,
      "languageTargeting": null,
      "deliveryType": null,
      "assetModuleType": null,
      "textureCompressionFormat": null
    }
  ]
}
```

# Enumerations Reference

This section lists all numeric enum values used across the Fullerene REST API requests, responses, and build `manifest.json` files.
### ReleaseChannel
| Value | Identifier | Description |
| :--- | :--- | :--- |
| `10` | `Stable` | Production-ready builds |
| `20` | `Beta` | Beta testing releases |
| `30` | `Alpha` | Alpha experimental builds |
### ArtifactType
| Value | Identifier            | Description                                                            |
| :---- | :-------------------- | :--------------------------------------------------------------------- |
| `1`   | `StandaloneUniversal` | Universal standalone APK containing code and resources for all targets |
| `2`   | `StandaloneSingleAbi` | Standalone APK built for a single specific CPU architecture            |
| `3`   | `BaseSplit`           | Base module split APK for Android App Bundle architecture              |
| `4`   | `AbiSplit`            | Native library CPU architecture split APK                              |
| `5`   | `DensitySplit`        | Screen density resources split APK                                     |
| `6`   | `LanguageSplit`       | Language/locale resources split APK                                    |
| `7`   | `AssetsSplit`         | Asset pack split APK                                                   |
| `8`   | `FeatureSplit`        | Dynamic feature module split APK                                       |
### CpuArchitecture
| Value | Identifier | ABI Target |
| :--- | :--- | :--- |
| `1` | `Armeabi` | `armeabi` |
| `2` | `ArmeabiV7a` | `armeabi-v7a` |
| `3` | `Arm64V8a` | `arm64-v8a` |
| `4` | `X86` | `x86` |
| `5` | `X86_64` | `x86_64` |
| `6` | `Mips` | `mips` |
| `7` | `Mips64` | `mips64` |
| `8` | `RiscV64` | `riscv64` |
### ScreenDensityAlias
| Value | Identifier | Target Density |
| :--- | :--- | :--- |
| `1` | `NODPI` | Any density (`nodpi` / 0 dpi) |
| `2` | `LDPI` | Low density (`ldpi` / ~120 dpi) |
| `3` | `MDPI` | Medium density (`mdpi` / ~160 dpi) |
| `4` | `TVDPI` | TV density (`tvdpi` / ~213 dpi) |
| `5` | `HDPI` | High density (`hdpi` / ~240 dpi) |
| `6` | `XHDPI` | Extra high density (`xhdpi` / ~320 dpi) |
| `7` | `XXHDPI` | Extra extra high density (`xxhdpi` / ~480 dpi) |
| `8` | `XXXHDPI` | Extra extra extra high density (`xxxhdpi` / ~640 dpi) |
### DeliveryType
| Value | Identifier | Description |
| :--- | :--- | :--- |
| `1` | `InstallTime` | Delivered during app installation |
| `2` | `OnDemand` | Downloaded on demand when requested by the app |
| `3` | `FastFollow` | Automatically downloaded immediately after app installation |
### AssetModuleType
| Value | Identifier | Description |
| :--- | :--- | :--- |
| `1` | `DefaultAssetType` | Standard asset pack module |
| `2` | `AIPackType` | AI/ML model or data asset pack module |
### FeatureModuleType
| Value | Identifier | Description |
| :--- | :--- | :--- |
| `1` | `FeatureModule` | Standard dynamic feature module |
| `2` | `MLModule` | Machine learning model feature module |
| `3` | `SdkModule` | Dynamic SDK dependency module |
### TextureCompressionFormat
| Value | Identifier     | Description                           |
| :---- | :------------- | :------------------------------------ |
| `0`   | `UNCOMPRESSED` | Uncompressed textures                 |
| `1`   | `ETC1_RGB8`    | Ericsson Texture Compression (ETC1)   |
| `2`   | `PALETTED`     | Paletted textures                     |
| `3`   | `THREE_DC`     | ATI 3Dc compression                   |
| `4`   | `ATC`          | Qualcomm AMD/ATI Texture Compression  |
| `5`   | `LATC`         | Luminance-Alpha Texture Compression   |
| `6`   | `DXT1`         | S3 Texture Compression (DXT1 / BC1)   |
| `7`   | `S3TC`         | General S3TC / DXT compression        |
| `8`   | `PVRTC`        | PowerVR Texture Compression           |
| `9`   | `ASTC`         | Adaptive Scalable Texture Compression |
| `10`  | `ETC2`         | Ericsson Texture Compression 2 (ETC2) |

# Licensing
Copyright (C) 2026 The Fullerene Contributors

This file is part of Fullerene.

Fullerene is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, only version 3 of the License.

Fullerene is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with Fullerene. If not, see <https://www.gnu.org/licenses/>. 