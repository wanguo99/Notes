**好的，明白了！你 NAS 上使用的是 Gitea 作为 Git Server，而不是群晖自带的 Git Server。**

Gitea 和 GitLab/GitHub 的使用方式几乎完全一样，Flyway 方案可以无缝适配。下面我给你**针对 Gitea 的完整、实用部署和使用指南**（专为群晖 NAS + OrCAD CIS 数据库设计）。

### 1. 整体推荐架构

- **Git 仓库**：在 Gitea 上新建一个仓库（推荐名称：`orcad-cis-db-migrations`）
- **迁移脚本**：全部放在这个仓库的 `db/migrations/` 目录下（版本化 SQL 文件）
- **执行方式**：
  - 日常开发：在本地电脑用 Docker 运行 Flyway
  - 正式应用到 NAS 的 MySQL：在群晖上通过 Docker 或 Shell 脚本运行 Flyway（推荐 Docker）

### 2. 第一步：在 Gitea 上创建仓库

1. 登录你的 Gitea（通常是 `http://nas-ip:3000`）。
2. 新建仓库：
   - 仓库名称：`orcad-cis-db-migrations`（建议公开或团队私有均可）
   - 初始化仓库（Add .gitignore 和 README）
   - 克隆地址示例：`http://nas-ip:3000/你的用户名/orcad-cis-db-migrations.git` 或 SSH 方式（推荐用 SSH）

3. 在本地克隆仓库：
   ```bash
   git clone http://nas-ip:3000/你的用户名/orcad-cis-db-migrations.git
   cd orcad-cis-db-migrations
   ```

### 3. 创建推荐目录结构

```bash
mkdir -p db/migrations config
```

最终结构如下：

```
orcad-cis-db-migrations/
├── db/
│   └── migrations/                 ← 所有迁移脚本必须放在这里
├── config/
│   └── flyway.conf                 ← 基础配置文件（可提交）
├── README.md
└── .gitignore
```

在 `.gitignore` 中加入：

```gitignore
flyway.conf.local
*.log
```

### 4. 配置 Flyway（推荐方式）

在 `config/flyway.conf` 中写入以下内容（**不要把密码提交到 Gitea**）：

```properties
# ====================== 数据库连接 ======================
flyway.url=jdbc:mysql://127.0.0.1:3306/你的_cis_数据库名?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Tokyo
flyway.user=你的数据库用户名
flyway.password=你的数据库密码          # ← 本地测试时可临时填写，生产建议用 -password 参数覆盖

# ====================== 迁移设置 ======================
flyway.locations=filesystem:db/migrations
flyway.baselineOnMigrate=true
flyway.validateOnMigrate=true
flyway.schemas=你的数据库名

# 可选：防止乱序执行
flyway.outOfOrder=false
```

**安全做法**：
- 把上面的 `flyway.conf` 提交到 Gitea（删掉 password 行）。
- 每个成员本地复制一份 `flyway.conf.local`，并加入 `.gitignore`，然后用命令行参数覆盖密码。

### 5. 使用 Flyway（最常用命令）

推荐使用 **Docker** 方式（不需要在每台电脑安装 Flyway）：

```bash
# 进入项目目录后执行

# 1. 查看当前迁移状态（强烈建议每次 migrate 前先看）
docker run --rm \
  -v "$(pwd)":/flyway \
  flyway/flyway:latest \
  -configFiles=/flyway/config/flyway.conf info

# 2. 执行迁移（核心命令）
docker run --rm \
  -v "$(pwd)":/flyway \
  flyway/flyway:latest \
  -configFiles=/flyway/config/flyway.conf migrate

# 3. 只校验脚本，不执行
docker run --rm \
  -v "$(pwd)":/flyway \
  flyway/flyway:latest \
  -configFiles=/flyway/config/flyway.conf validate
```

**带密码覆盖的写法**（推荐生产/本地都这么用）：

```bash
docker run --rm \
  -v "$(pwd)":/flyway \
  flyway/flyway:latest \
  -configFiles=/flyway/config/flyway.conf \
  -url=jdbc:mysql://nas-ip:3306/你的数据库名 \
  -user=用户名 \
  -password=你的密码 \
  migrate
```

### 6. 在群晖 NAS 上执行迁移（正式环境）

推荐两种方式：

**A. 最简单：手动用 Docker 运行**（适合目前阶段）

在群晖的 **Docker** 或 **SSH终端** 中执行上面带密码的 migrate 命令（把 volume 挂载到你 clone 的仓库路径）。

**B. 写一个方便的 Shell 脚本**（推荐）

在群晖上创建一个脚本 `run-flyway.sh`，内容类似：

```bash
#!/bin/bash
cd /volume1/git/orcad-cis-db-migrations     # 改成你实际 clone 的路径

docker run --rm \
  -v "$(pwd)":/flyway \
  flyway/flyway:latest \
  -configFiles=/flyway/config/flyway.conf \
  -password=你的生产密码 \
  migrate
```

然后把脚本加入群晖的 **任务计划**，需要更新时手动触发即可。

### 7. 团队协作流程（Gitea）

1. 成员 pull 最新代码（`git pull`）。
2. 需要修改数据库 → 新建一个 migration 文件，例如：
   - `db/migrations/V20260505__add_orcad_cis_part_attributes.sql`
3. 写完后 commit 并 push 到 Gitea。
4. 其他成员 pull 后，在本地运行 `flyway migrate` 更新自己的测试环境。
5. 需要更新 NAS 正式数据库时，由指定人员在群晖上运行 migrate。

**重要规则**：
- 已经执行过的 migration 文件**永远不要修改**（Flyway 会校验 checksum）。
- 如果需要修复，用新的 migration 文件。
- 建议团队约定：版本号使用 `V年月日__描述` 格式，避免冲突。

---

**接下来请告诉我，你想让我立刻给你哪部分更详细的内容？**

1. OrCAD CIS 常用的迁移脚本示例（parts 表、供应商映射表等）。
2. 群晖上完整的 Shell 脚本 + 如何加入任务计划。
3. 如何安全管理密码（不写死在配置文件）。
4. 如何结合 Navicat 使用（Navicat 修改后生成 SQL 提交到 Gitea）。
5. Gitea + Flyway 的分支工作流（feature branch 等）。

请直接告诉我编号或具体需求，我马上给你对应内容。