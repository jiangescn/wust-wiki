# 0.6.1 滑块回归与测量

用户在 ARM64 手机报告0.6.0累计五次登录失败，最后错误为 slider_rejected、学校业务码0。旧模拟器单次成功属于历史快照，不能证明手机可用。

## 测量合同

- 使用实际 `SchoolAuthentication.verifyCaptcha(withService:true)`、实际 Android 解码／AES 和实际学校接口；不读取或提交账号密码。
- 在 API37 x86_64 模拟器以 Flutter AOT profile 运行。profile继承debug构建类型，只为写应用私有计数；普通release入口不包含该测试流程。
- 每轮是新匿名会话，最多三张验证码。每张取到的验证码都入分母，包括没有可靠匹配、业务拒绝与格式错误。只有服务器 errorCode=1 进入成功分子；网络／初始化失败计入轮失败并单列。
- 同时报告单张完整处理成功率和三张以内轮成功率，不将HTTP200当验证成功，不将模拟器数字称为手机成功率。失败不删除，样本数量预先固定。
- 原轨迹先测五轮；修复后固定三十轮，不在出现一次成功后停止。两组是顺序执行，不能排除服务时段与图片难度差异，因此不归因某一个改动的独立改善幅度。
- 测量期间不运行Gradle构建；基线开始前主机CPU观测为7%。记录每张实际耗时与返回数字码，作为环境噪声边界。

入口 `lib/foundation/slider_acceptance_main.dart`，结果只含计数、匹配分数、几何尺寸、耗时与错误码，保存在应用私有 dart-acceptance.json。不写图像、AES密钥、Cookie值、学号或密码。

## 已复现

`verification/slider-baseline.json`：原0.6.0轨迹五轮中一轮通过，共十四张验证码中一张被服务器接受；其他失败全部保留。该样本复现低成功率，不能单独代表旧Swift版本。

`verification/slider-motion-before.log`：原末点计算在部分非整位移下与提交moveLength不全等。旧Swift末点进度为1，新Dart原实现先乘再除产生浮点差异。

## 修复内容

保留相关匹配算法和位移，不降低0.65置信度／0.03差值门槛。轨迹加入有限加减速、小幅横向噪声、上下随机漂移和间隔变化，采样遵循官方组件20ms／2px约束并保留释放点。末点直接使用moveLength本值。

移动按轨迹逐段等待，c记录实际相邻等待完成间隔，避免一次等待后提交预设但与实际调度不符的时序。取消仍逐段可中断；累计首次加四次登录重试不变，每轮滑块最多三次不变。

`verification/slider-motion-after.log` 验证准确终点、坐标边界、独立轨迹差异和速度变化；`verification/slider-regression.log` 验证原五次、并发与取消约束。真实结果须待固定样本结束后填写，当前不提前宣称手机修复通过。

## 复跑

```sh
flutter build apk --profile --target=lib/foundation/slider_acceptance_main.dart --target-platform android-x64 --dart-define=SLIDER_ROUNDS=30 --dart-define=SLIDER_LABEL=timed-motion-0.6.1
```

安装这个专用profile包到测试模拟器并启动MainActivity即可开始；不得把专用测量包作为正式用户包分发。最终发布从正常lib/main.dart构建release，需另验实际账号登录及恢复。

## 中间版本：只加入变速与漂移

加入实际等待、变速与漂移但尚未补足短距离时长的中间版本，30轮匿名新会话共处理52张验证码，服务器接受26张：单张完整处理26/52（50.0%），每轮最多三张26/30（86.7%）。其余26张分为4张本地无可靠定位、22张服务器业务码0。没有把后两类算成功。源记录为 verification/slider-varied.json，聚合为 slider-success-summary.json。

原0.6.0小样本为1/14单张、1/5轮；这不等于用户所说的旧Swift包，也不足以精确归因某个改动的改善幅度。

## 定位与运动提交隔离

另外五张公开验证码独立于上述成功率样本。先保持真实间隔、使用线性XY，再在首次返回0时使用同一图片、同一密钥、同一最终坐标改为变速漂移坐标与实际间隔重新提交。不重新取图，不修改定位或放宽阈值，数据只存在应用内存，不落地密钥／Cookie。

其中第3例在偏移150、匹配分数约0.733时先0后1，定位叠加图对齐，说明至少这一例可排除定位坐标错误，拒绝属于运动数据／时序提交侧。其余四例线性XY也直接通过，因此不能声称“只要线性或像机器就一定拒绝”，学校没有给出具体拒绝规则。该小样本不能推广到全部业务码0。

工具入口 lib/foundation/slider_isolation_main.dart，仅用于匿名诊断，不进入正常main；结果见 verification/slider-location-isolation.json。同图再次提交可能被服务端消费／过期策略影响，0→0本身不能证明定位错误。截图是公开验证码图像，不含账号，不作为App素材分发。

## 相同密文，仅延后提交

为区分轨迹与时序，另固定五张公开验证码。首次返回0时，保持同图、同坐标、同一份AES密文及Cookie头，只增加等待后重发。四例首次0、稍后1，一例首次直接1；四例均记录ciphertextUnchanged与cookieUnchangedAfterFirst=true。见 verification/slider-timing-isolation.json。

中间版本22个业务码0的耗时997–1563ms，26个成功的耗时1555–2466ms。结合相同密文的结果，更支持提交过早／时长因素；无法直接获知学校内部规则，也不能完全排除服务端重试状态影响。线性坐标也曾直接成功，不能据此宣称路径像程序就是根因。

最终版本仅对较短轨迹延长计划间隔，总计划时长至少随机1800–2300ms；仍逐点实际等待并提交实际间隔。较长轨迹不会被压短。该范围来自本次测量后的工程裕量，并非学校公开的协议常量。固定30个新匿名会话另测首次提交与有界重试效果，不把上述同图重发作为生产登录策略。verification/slider-duration-before.log为短距离预算回归失败，slider-duration-after.log为修复后通过。

## 最终固定30轮结果

最终补足时长版本：30个新匿名会话，共取得34张验证码。30张被学校errorCode=1接受，4张为本地slider_no_match，没有业务码0、网络／初始化失败。单张完整处理成功率30/34（88.24%）；每轮第一张26/30（86.67%）；每轮最多三张的成功率30/30（100%）。提交到服务器的30张均通过，不能据此称所有图片都能正确定位。

结果来自同一台API37 x86_64模拟器的Flutter AOT profile，不是ARM64手机成功率，不代表长期100%。同图延后诊断样本没有混入本次30轮。完整样本见 verification/slider-final.json，汇总见 verification/slider-success-summary.json；可用 python scripts/summarize-slider.py verification/slider-final.json 复核分母与失败。
