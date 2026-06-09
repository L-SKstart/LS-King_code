# LS-King_code

Shell 脚本工具集

## 文件说明

### `cime_xml_extract.sh`
从阿里云 OSS 下载压缩包并解压提取 XML 文件的自动化脚本。

**功能：**
- 支持多种日期输入方式（当天/单个日期/日期范围）
- 从 OSS 下载 `.tar.gzaa` 压缩包
- 3 层解压流程（gunzip → tar → gunzip xml）
- 自动查找并提取目标 XML 文件

**用法：**
```bash
# 处理当天
./cime_xml_extract.sh

# 处理指定日期
./cime_xml_extract.sh 20260604

# 处理日期范围
./cime_xml_extract.sh 20260601,20260605
```
