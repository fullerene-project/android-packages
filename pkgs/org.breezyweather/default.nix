{ channels }:

let
  pkgs = channels.n25_11;

  aab = pkgs.fetchurl {
    url = "https://github.com/fullerene-project/android-packages/raw/a8d9cfa9057b60fab48f765e50799446bfe946d1/pkgs/org.breezyweather/app-freenet-release.aab";
    sha256 = "71ce383d995797f9b3ee5400bd028b936bcae7085bd1961f6fb0aef3e59424e4";
  };

  breezyPackage = pkgs.stdenv.mkDerivation {
    pname = "breezy-weather";
    version = "6.2.1";

    src = aab;
    dontUnpack = true;

    nativeBuildInputs = [
      pkgs.openjdk21_headless
      pkgs.bundletool
      pkgs.aapt
      pkgs.unzip
      pkgs.python3
    ];

    buildPhase = ''
      bundletool build-apks \
        --bundle="$src" \
        --output=splits.apks \
        --aapt2="${pkgs.aapt}/bin/aapt2"

      bundletool build-apks \
        --bundle="$src" \
        --output=universal.apks \
        --aapt2="${pkgs.aapt}/bin/aapt2" \
        --mode=universal

      mkdir -p extracted_apks
      unzip splits.apks -d extracted_apks
      unzip -o universal.apks -d extracted_apks
    '';

    installPhase = ''
      mkdir -p "$out"
      export INPUT_DIR="extracted_apks"
      export OUTPUT_DIR="$out"

      python3 - <<'EOF'
      import os
      import sys
      import re
      import json
      import hashlib
      import subprocess
      import glob
      import shutil

      abi_map = {
          'armeabi': 1, 'armeabi-v7a': 2, 'armeabi_v7a': 2,
          'arm64-v8a': 3, 'arm64_v8a': 3, 'x86': 4, 'x86_64': 5,
          'mips': 6, 'mips64': 7, 'riscv64': 8
      }

      density_map = {
          'nodpi': 1, 'ldpi': 2, 'mdpi': 3, 'tvdpi': 4,
          'hdpi': 5, 'xhdpi': 6, 'xxhdpi': 7, 'xxxhdpi': 8
      }

      def get_sha256_and_size(filepath):
          h = hashlib.sha256()
          size = 0
          with open(filepath, 'rb') as f:
              while chunk := f.read(65536):
                  h.update(chunk)
                  size += len(chunk)
          return h.hexdigest(), size

      def parse_badging(apk_path):
          try:
              result = subprocess.run(
                  ["aapt2", "dump", "badging", apk_path],
                  capture_output=True, text=True, check=True
              )
              return result.stdout
          except Exception as e:
              print(f"Error analyzing {apk_path}: {e}", file=sys.stderr)
              return ""

      def get_apk_architectures(badging):
          match = re.search(r"native-code:\s*(.*)", badging)
          if match:
              raw_abis = re.findall(r"'([^']+)'", match.group(1))
              mapped = []
              for abi in raw_abis:
                  if abi in abi_map:
                      mapped.append(abi_map[abi])
              if mapped:
                  return sorted(list(set(mapped)))
          return []

      def main():
          input_dir = os.environ["INPUT_DIR"]
          output_dir = os.environ["OUTPUT_DIR"]

          splits = sorted(list(set(glob.glob(os.path.join(input_dir, "splits/**/*.apk"), recursive=True))))
          standalones = sorted(list(set(glob.glob(os.path.join(input_dir, "standalones/**/*.apk"), recursive=True))))
          universals = sorted(list(set(
              glob.glob(os.path.join(input_dir, "universal.apk")) + \
              glob.glob(os.path.join(input_dir, "**/universal.apk"), recursive=True)
          )))

          entries = []

          def process_apk(apk_path, category):
              filename = os.path.basename(apk_path)
              sha256, size = get_sha256_and_size(apk_path)
              badging = parse_badging(apk_path)

              if category == "standalone":
                  dest_filename = f"standalone-{filename}"
              elif category == "universal":
                  dest_filename = "base-universal.apk"
              else:
                  dest_filename = filename

              version_code = 1
              min_sdk = 23
              target_sdk = 36
              split_id = None

              vc_match = re.search(r"versionCode='(\d+)'", badging)
              if vc_match:
                  version_code = int(vc_match.group(1))

              split_match = re.search(r"split='([^']+)'", badging)
              if split_match:
                  split_id = split_match.group(1)

              min_sdk_match = re.search(r"(?:sdkVersion|minSdkVersion):'(\d+)'", badging)
              if min_sdk_match:
                  min_sdk = int(min_sdk_match.group(1))

              target_sdk_match = re.search(r"targetSdkVersion:'(\d+)'", badging)
              if target_sdk_match:
                  target_sdk = int(target_sdk_match.group(1))

              filename_no_ext = os.path.splitext(filename)[0]
              parts = filename_no_ext.split('-')
              module_name = parts[0] if len(parts) > 1 else "base"

              artifact_type = None
              cpu_architectures = []
              single_cpu_architecture = None
              density_alias = None
              language_targeting = None

              if category == "split":
                  if not split_id:
                      artifact_type = 3  # BaseSplit
                      split_id = ""
                  else:
                      if split_id == module_name:
                          artifact_type = 8  # FeatureSplit
                      else:
                          suffix = split_id.split('.')[-1]
                          if suffix in abi_map:
                              artifact_type = 4  # AbiSplit
                              single_cpu_architecture = abi_map[suffix]
                              cpu_architectures = [single_cpu_architecture]
                          elif suffix in density_map:
                              artifact_type = 5  # DensitySplit
                              density_alias = density_map[suffix]
                          else:
                              artifact_type = 6  # LanguageSplit
                              language_targeting = suffix
              elif category == "standalone":
                  split_id = None
                  real_archs = get_apk_architectures(badging)
                  if len(real_archs) == 1:
                      artifact_type = 2  # StandaloneSingleAbi
                      single_cpu_architecture = real_archs[0]
                      cpu_architectures = real_archs
                  else:
                      artifact_type = 1  # StandaloneUniversal
                      cpu_architectures = real_archs
              elif category == "universal":
                  split_id = None
                  artifact_type = 1  # StandaloneUniversal
                  cpu_architectures = get_apk_architectures(badging)

              entry = {
                  "fileName": dest_filename,
                  "fileSha256": sha256,
                  "fileSizeBytes": size,
                  "artifactType": artifact_type,
                  "minApiLevel": min_sdk,
                  "targetApiLevel": target_sdk,
                  "versionCode": version_code,
                  "splitId": split_id,
                  "moduleName": module_name,
                  "cpuArchitectures": cpu_architectures,
                  "singleCpuArchitecture": single_cpu_architecture,
                  "densityAlias": density_alias,
                  "densityDpi": None,
                  "languageTargeting": language_targeting,
                  "deliveryType": None,
                  "assetModuleType": None,
                  "textureCompressionFormat": None
              }

              shutil.copy2(apk_path, os.path.join(output_dir, dest_filename))
              entries.append(entry)

          for apk in splits:
              process_apk(apk, "split")
          for apk in standalones:
              process_apk(apk, "standalone")
          for apk in universals:
              process_apk(apk, "universal")

          manifest_data = {
              "entries": entries,
              "releaseChannel": 10
          }

          with open(os.path.join(output_dir, "manifest.json"), "w") as f:
              json.dump(manifest_data, f, indent=2)

      if __name__ == "__main__":
          main()
      EOF
    '';

    passthru = {
      androidApplicationId = "org.breezyweather";
      logoUrl = "https://raw.githubusercontent.com/breezy-weather/breezy-weather/main/fastlane/metadata/android/en-US/images/icon.png";
      baseVersionCode = 60201;
      appVersionString = "6.2.1";
      releaseChannel = 10;
      appReleaseDate = "2026-06-07T00:00:00Z";
      releaseNotes = "
      Improvements and fixes
                      
          Cap temperature animation duration to 1 to 2 seconds
          Ensure pollutant and pollen concentrations are always positive to avoid a rare case of crash when some sources provide negative concentrations
          Notification widget - Daily - Fix reversed feels like setting
                      
      Security
                      
          Enable Arm memory tagging (MTE) asynchronous mode
                      
      Sources
                      
          AEMET - Fix current visibility and night wind speed units
          China - Use a server which is less likely to return invalid data when language is set to Chinese
          KNMI - Fix duplicate “Today” when migrating from another source
          KNMI - Fix precipitation probability being 100 times too low
          Recosanté - Removed source will no longer be available for choice in the source selection screens";
      nixPackageRevision = 1;

      appName = "Breezy Weather";
      appSummary = "A Material Design Weather Application";
      appDescription = "A feature-rich weather app with good visualizations and more than 50 sources.";
      appLicense = "LGPL-3.0-only";
    };
  };

in {
  package = breezyPackage;

  devShell = pkgs.mkShell {
    buildInputs = [
      pkgs.openjdk21_headless
      pkgs.bundletool
      pkgs.aapt
    ];
  };
}