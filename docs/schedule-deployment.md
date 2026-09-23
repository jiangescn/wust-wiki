# 学校课表后端

Wiki 正式域名：**https://wiki.wustacm.com**，保持现有 Nuxt/Docus 静态部署与页面外壳。
课表 API：**https://schedule.wiki.jianges.com/api/login-template**，不承载网站或独立登录页面。

## Wiki 调用

`nuxt.config.ts` 的 `public.scheduleApiBase` 默认指向上述后端；可通过 `NUXT_PUBLIC_SCHEDULE_API_BASE` 覆盖。静态构建时确定该值，修改后必须重新生成并发布 Wiki。`pnpm dev:login` / `pnpm dev:login:lan` 仍使用本地实验接口。

`content/2.study/2.curriculum.md` 通过 `::schedule-curriculum` 嵌入查询入口，默认仍由 `app/components/content/ScheduleQuery.vue` 展示学校微信扫码、当前学期课表与教务备注；`?schedule=sample` 显示独立虚构课表样例，不请求登录 API。查询组件复用原登录模板的轮询、取消与临时会话逻辑，在页面内存中保存短期会话标识；离开页面或手动取消时释放临时登录会话；已成功同步的课程字段另由浏览器保留七天，“清除本机课表”立即删除该缓存。`app/pages/previews/schedule-login.vue` 通过 `ScheduleLoginTemplates.vue` 保留三种方式的本地测试。前端发布沿用 GitHub main → Vercel；正式访问地址为 `https://wiki.wustacm.com/study/curriculum`。

后端精确允许 `Origin: https://wiki.wustacm.com`，支持 POST 的 CORS 预检及 `Content-Type, Authorization`。不使用第三方 Cookie：Wiki 与后端属于不同主域名，单纯放开 CORS 无法保证第三方 Cookie 可用。

调用同一个 POST 地址，JSON 请求如下：

| 动作 | 请求体 | 用途 |
| --- | --- | --- |
| inspect | `{"action":"inspect"}` | 首次取得 `sessionToken`、登录方式和状态 |
| start | `{"action":"start","provider":"wust"}` | 创建学校微信二维码 |
| poll | `{"action":"poll"}` | 每 3.5 秒查询，成功时返回 `result` |
| clear | `{"action":"clear"}` | 取消并销毁当前会话 |

首次请求后，将返回的 `sessionToken` 通过 `Authorization: Bearer <sessionToken>` 带回。使用 `credentials: 'omit'`，不要存入 URL、localStorage、日志或静态文件。它只是本服务随机生成、绑定来源且有效期十分钟的会话标识，**不是学校 Cookie、票据或密码**。401 表示会话失效，应清除标识后重新开始。不同页面会话隔离；清除后旧标识失效。

学校认证材料只保存在服务端内存中，成功、失败、取消或到期后清除。结果最多暂存五分钟。服务重启会中断当前扫码。每 IP 每分钟最多 6 次新二维码、180 次 API 请求，同时最多 20 个临时会话；这些是保护限制，不是并发压测结果。

## 部署与维护

- 服务器：用户指定的 `139.224.226.170`，SSH `2222`。
- 当前版本：`20260923-2`，容器 `wust-schedule`，镜像 `wust-schedule:20260923-2`。
- `/opt/wust-schedule/current` 指向 `releases/20260923-2`。更新时保留 Docker Compose 项目名 `20260923-1`，避免与现有同名容器冲突；该项目名是首次部署时生成的标识。
- Node HTTP 入口为 `server/schedule-service.mjs`，直接复用学校扫码适配器、Cookie jar、课表解析器与会话存储。
- 非 root、只读容器，内存上限 256 MB，仅映射 `127.0.0.1:3018`；现有 OpenResty 通过 HTTPS 转发。不新增公网应用端口，不改已有网站。
- OpenResty 配置：`/opt/1panel/www/conf.d/schedule.wiki.jianges.com.conf`。代理覆盖 `X-Real-IP`，供应用限流；不要将容器端口暴露到公网。
- 证书与 ACME 验证目录：`/opt/1panel/www/sites/schedule.wiki.jianges.com/`。证书到期日 `2026-12-22`，`wust-schedule-cert-renew.timer` 每日检查续期，续期演练已通过。私钥只保存在服务器。

本地打包只包含后端和配置，不包含 Wiki 静态产物、SSH 密钥、个人课表或认证材料：

```powershell
pnpm check:login-templates
node scripts/package-schedule-service.mjs
tar -czf .cache/wust-schedule-20260923-2.tar.gz -C .cache/schedule-release-20260923-2 .
```

服务器维护：

```sh
cd /opt/wust-schedule/current
docker compose -p 20260923-1 up -d
docker inspect wust-schedule --format '{{.State.Health.Status}}'
docker logs --tail 30 wust-schedule
systemctl status wust-schedule-cert-renew.timer
```

## 验证边界

2026-09-23：16 项自动测试、类型检查、Wiki 静态生成通过；公网上以 Wiki Origin 验证 OPTIONS、inspect、二维码创建、轮询、隔离、清除均通过，不使用 Cookie。错误域名返回 403，原独立页面返回 404，根路径仅返回服务状态 JSON。HTTPS、自动续期演练与原有宿舍站点响应通过。

学校完整课表读取此前已在本地真实扫码验证。服务器上此前一次用户确认未观察到最终课程结果，不能写成已验证；当前后端已确认二维码和等待轮询可用。正式 Wiki 的浏览器端验收需在其下次构建发布后完成。
