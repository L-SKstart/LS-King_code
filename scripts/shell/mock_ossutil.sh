#!/bin/bash
# ============================================================================
# 脚本名称：mock_ossutil.sh
# 用途：模拟阿里云 ossutil 命令行工具，用于在没有真实 OSS（对象存储）连接的
#       情况下进行本地测试。让脚本开发和调试不需要每次都连真实 OSS。
# 用法：mock_ossutil.sh ls [参数]     # 模拟列出 OSS 上的文件
#       mock_ossutil.sh sync [参数]   # 模拟从 OSS 下载文件到本地
# 前提：需要先在 /tmp/oss_mock_data 目录中放入模拟的 .tar.gz 文件
#       这些文件就是"假的 OSS 文件"，测试时用它们代替真实的 OSS 文件
# ============================================================================

M=$1                                                      # 第一个参数：操作模式。调用方必须传 "ls" 或 "sync"
S=/tmp/oss_mock_data                                      # 模拟数据存放目录。把假数据文件放这里，脚本从这读

case $M in
  ls)
    # ========== ls 模式：模拟"列出 OSS 上的文件" ==========
    # 真实场景中，ossutil ls 会列出 OSS bucket 中的文件列表
    # 这里我们根据调用方传入的 --include 参数，拼出对应的假文件路径返回
    
    D=""                                                  # D 用于存放提取出来的日期前缀（如 20250601）
    for a in "$@"; do
      # 遍历所有参数，找到 --include=20250601* 这样的参数
      # ${a#--include=} 的意思是：去掉参数开头的 "--include="，只留下后面的日期
      [[ $a == --include=* ]] && D="${a#--include=}"
    done
    D="${D%\*}"                                           # 去掉末尾的 * 通配符（ossutil 用 * 做模糊匹配）
    
    if [ -n "$D" ]; then
      # 如果能提取到日期前缀，就输出4个模拟文件（2组：input+output，模拟真实 OSS 的文件分布）
      echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133810.tar.gz"
      echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133810_output.tar.gz"
      echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133922.tar.gz"
      echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133922_output.tar.gz"
      echo "Object and Directory Number is: 4"            # 模仿真实 ossutil 的统计尾巴，必须输出
    fi
    # 注意：如果 D 为空（没匹配到 --include），就什么都不输出
    # 这模拟了 OSS 上没有对应文件的情况
    ;;
    
  sync)
    # ========== sync 模式：模拟"从 OSS 下载文件到本地" ==========
    # 真实场景中，ossutil sync 会把 OSS 上的文件下载到本地指定目录
    # 我们这里直接从模拟数据目录 S 复制文件到目标目录 T
    
    P=""                                                  # P 用于存放文件前缀（从 --include 提取）
    T=""                                                  # T 用于存放本地目标目录路径
    
    for a in "$@"; do
      [[ $a == --include=* ]] && P="${a#--include=}"     # 提取 --include=20250601* 中的日期前缀
      [[ $a == /tmp/* ]] && T="$a"                        # 提取以 /tmp/ 开头的本地目标路径
    done
    
    T="${T%/}"                                            # 去掉目标路径末尾可能多余的 /
    P="${P%\*}"                                           # 去掉前缀末尾的 * 通配符
    
    # 只有当提取到了前缀P、且模拟数据目录S存在时，才执行复制
    # 这两个条件缺一个就什么都不做——模拟 OSS 无文件或目标不存在的情况
    if [ -n "$P" ] && [ -d "$S" ]; then
      for f in "$S"/*"$P"*.tar.gz; do                    # 遍历模拟目录中文件名包含日期前缀的 .tar.gz 文件
        [ -f "$f" ] && cp "$f" "$T/" 2>/dev/null         # 如果确实是文件（不是目录），就复制到目标目录
                                                         # 2>/dev/null 吞掉复制失败时的错误信息，避免干扰
      done
    fi
    ;;
esac
exit 0                                                    # 始终返回成功，模拟工具不给真实 ossutil 加额外复杂度
