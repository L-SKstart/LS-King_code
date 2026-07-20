StabilityRule
 └─ SupervisionCondition
    ├─ @desc
    ├─ Def
    └─ VarDef
       └─ Measurement
          ├─ @dev_type
          ├─ @meas_type
          └─ @station

```

### physicalType 判定规则表

| physicalType | 类型 | 判断依据 |
|:-----------:|:----:|---------|
| 1 | 常规断面 | 条件设备Measurement为空，并且SupervisonCondition@desc为空；或者desc包含正常方式、正常运行 |
| 2 | 运行方式控制断面 | remark或desc包含关键词：投入、退出、功能、运行、上网、合环、分母、开#、断开、措施、断环、分列；或者条件设备全是Breaker且station包含站；或者条件设备全是线路/直流设备且meas_type=Pos；或者条件设备为空但desc非空且不是正常方式 |
| 3 | 机组开停控制断面 | 条件设备全部满足：dev_type=GeneratorUnit且meas_type=Pos |
| 4 | 机组出力/线路潮流控制断面 | 条件设备全部满足：dev_type属于Line、ACLineSegmentDot、DCLineSegmentDot、DClineSegment、DCPole、GeneratorUnit，并且meas_type=P |
| 5 | 运行方式+条件控制断面 | 同时满足2的运行方式控制判断，并且还满足3或4 |
| 6 | 机组开停+机组出力/线路潮流控制断面 | 条件设备里既有GeneratorUnit+Pos，又有线路/直流/机组类设备的P，且所有条件设备都属于这两类 |

⏱️⏱️ 07-16 16:30

---
⏱️ 07-16 16:30

------
