UPacTool

An integration package tool for Spreadtrum devices, which can be used to package or flash integration packages. Its key feature is the ability to retain data state (excluding /sdcard, meaning files such as photos and downloads will not be preserved), allowing devices of the same model to exchange integration packages and achieve an identical user experience. Currently, this is still an immature tool, and the author has merely integrated simple mature solutions. The core technology is sourced from the Huaqiangbei Smartwatch Geek Alliance, group number 1031894167. Welcome to join us!

一个用于展讯设备的整合包工具，你可以用它来打包或者刷入整合包，它的特点是可以保留data数据状态（不包括/sdcard，这意味着你的照片，下载的文件等不会被保留），让相同型号的设备可以互相交换整合包，并获得相同的体验。现在这只是一个不成熟的工具，作者只是做了简单的成熟方案整合，主要技术来源于华强北手表极客联盟，群号1031894167，欢迎加入我们。

spd_dump
Purpose: Core flashing utility for communicating with Unisoc (Spreadtrum) devices in BROM mode.

Source: https://github.com/TomKing062/spreadtrum_flash


Status Declaration:

This tool was developed by a community developer, and its GitHub repository does not specify an explicit open-source license.
Given that this tool has been widely used, modified, and distributed within the Huaqiangbei (HQB) hardware development community, and considering the original repository is public and read-only, we have included it in this package for the purpose of technical promotion and exchange.
We extend our sincere gratitude to the original author. If you are the original author and have any concerns regarding its inclusion, please contact us via a GitHub Issue, and we will promptly address your request.

Acknowledgement: We thank the anonymous developer for their contribution to the community.

Android Debug Bridge (ADB) and Fastboot
Purpose: Communicating with the device in Android and Recovery modes.

Source: https://developer.android.com/tools/releases/platform-tools

License: Apache License 2.0

License Text: See the NOTICE file in the bin/adb_fastboot/ directory.

7-Zip (7zr)
Purpose: Extracting the firmware package.

Source: https://www.7-zip.org/

License: GNU Lesser General Public License (LGPL)

License Text: See the License.txt file in the bin/7z/ directory.

Disclaimer: The remainder of this project (the batch script logic, structure, and design) is authored by 独の光 (Du Guang) and is licensed under the GNU General Public License v3.0 (GPL-3.0). The licensing status of third-party tools is determined by their respective authors and is independent of the author of this project.



# 第三方版权与声明

本项目使用了以下第三方工具，特此声明并感谢原作者的贡献。

## spd_dump
- **用途**：核心刷写工具，用于与展锐（Unisoc）设备在BROM模式下通信。
- **来源**：https://github.com/TomKing062/spreadtrum_flash
- **状态声明**：
  > 此工具由社区开发者开发，其GitHub仓库未声明明确的开源许可证。
  > 鉴于该工具已在华强北硬件开发社区内被广泛使用、修改和传播，且原仓库处于公开只读状态，本项目基于技术推广和交流的目的将其纳入整合包。
  > 我们在此对原始作者表示由衷的感谢。如果您是原始作者并认为此举不妥，请通过Issue联系我们，我们将第一时间遵照您的要求进行处理。
- **致谢**：感谢无名开发者对社区做出的贡献。

## Android Debug Bridge (ADB) and Fastboot
- **用途**：与设备在Android和Recovery模式下通信。
- **来源**：https://developer.android.com/tools/releases/platform-tools
- **许可证**：Apache License 2.0
- **许可证全文**：参见 `bin/adb_fastboot/NOTICE` 文件。

## 7-Zip (7zr)
- **用途**：解压整合包。
- **来源**：https://www.7-zip.org/
- **许可证**：GNU Lesser General Public License (LGPL)
- **许可证全文**：参见 `bin/7z/License.txt` 文件。

---
**免责声明**：本项目的其他部分（批处理脚本逻辑、结构设计）由作者（独の光）采用 GNU General Public License v3.0 (GPL-3.0) 许可。第三方工具的许可状态由其各自作者决定，与本项目作者无关。

