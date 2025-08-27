# UPacTool

A specialized integration and flashing tool designed for Unisoc (Spreadtrum) devices. It supports creating and flashing integration packages, with its core feature being the ability to preserve the device's data partition state during the flashing process (excluding /sdcard, meaning user photos, downloaded files, etc., will not be retained). This enables devices of the same model to exchange integration packages and achieve identical user experiences.

Please note that this tool is still in its early development stage. The author has primarily integrated existing mature solutions. The core flashing technology originates from the Huaqiangbei Smartwatch Geek Alliance (Group ID: 1031894167). Developers interested in collaboration are welcome to join and exchange ideas!

---

## Third-Party Tool Copyright Statement

This project integrates and utilizes the following third-party tools. We hereby declare their copyright and source information:

### 1. spd_dump
- **Function**: Core flashing utility for communicating with Unisoc devices in BROM mode.
- **Source**: https://github.com/TomKing062/spreadtrum_flash
- **Usage Statement**:
  > This tool was developed by community developers, and its original repository did not explicitly declare an open-source license. Given its widespread use, modification, and distribution within the Huaqiangbei hardware developer community, and considering the original repository is publicly read-only, this project includes it for the purpose of technical promotion and exchange. We extend sincere gratitude to the original author. If you believe this usage is inappropriate, please contact us via a GitHub Issue, and we will respond promptly to address your concerns.
- **Acknowledgement**: Thanks to the anonymous developer for their contributions to the open-source community.

### 2. Android Debug Bridge (ADB) and Fastboot
- **Function**: Used to communicate with devices in Android and Recovery modes.
- **Source**: https://developer.android.com/tools/releases/platform-tools
- **License**: Apache License 2.0

### 3. 7-Zip (7zr)
- **Function**: Used to extract firmware packages.
- **Source**: https://www.7-zip.org/
- **License**: GNU Lesser General Public License (LGPL)

---

## Disclaimer

Except for the aforementioned third-party tools, the batch script logic, structural design, and implementation in this project are authored by 独の光 (Du Guang) and are licensed under the GNU General Public License v3.0 (GPL-3.0). The licensing status of third-party tools is determined by their respective authors and is independent of the author of this project.

# UPacTool

一个专为展讯（Unisoc）设备设计的集成化打包与刷机工具。支持制作及刷写设备整合包，其核心特性是在刷机过程中可保留设备的 data 分区数据状态（不包括 /sdcard，即用户照片、下载文件等不会被保留）。这使得同一型号的设备可通过交换整合包实现完全一致的用户体验。

请注意，当前该工具仍处于早期开发阶段，作者主要对现有成熟方案进行了整合与集成。核心刷机技术源自华强北手表极客联盟（群号：1031894167），欢迎感兴趣开发者加入交流！

---

## 第三方工具版权声明

本项目集成并使用了以下第三方工具，特此声明版权及来源信息：

### 1. spd_dump
- **功能**：核心刷写工具，用于与展锐设备在 BROM 模式下通信。
- **来源**：https://github.com/TomKing062/spreadtrum_flash
- **使用声明**：
  > 该工具由社区开发者开发，其原始仓库未明确声明开源许可证。鉴于其已在华强北硬件开发者社区中被广泛使用、修改与传播，且原仓库为公开只读状态，本项目出于技术推广与交流的目的将其纳入工具包。我们由衷感谢原始作者的贡献，如您认为该使用方式存在不妥，请通过 GitHub Issue 联系我们，我们将及时响应并处理您的诉求。
- **致谢**：感谢匿名开发者对开源社区所作出的贡献。

### 2. Android Debug Bridge (ADB) 与 Fastboot
- **功能**：用于在 Android 和 Recovery 模式下与设备进行通信。
- **来源**：https://developer.android.com/tools/releases/platform-tools
- **许可证**：Apache License 2.0

### 3. 7-Zip (7zr)
- **功能**：用于解压固件包。
- **来源**：https://www.7-zip.org/
- **许可证**：GNU Lesser General Public License (LGPL)

---

## 免责声明

除上述第三方工具外，本项目中的批处理脚本逻辑、结构设计与实现均由作者（独の光）编写，采用 GNU General Public License v3.0 (GPL-3.0) 许可。第三方工具的许可状态由其各自作者决定，与本项目作者无关。

