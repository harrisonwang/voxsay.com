---
categories: [编程语言, Node.js]
date: 2024-11-03 19:58:00 +0800
last_modified_at: 2024-11-03 19:58:00 +0800
tags:
- DSL
- VPS
title: 如何基于自定义 DSL 构建 VPS 库存监控任务
---

在尝试了多种 VPS 服务商后，我逐渐意识到选择合适的 VPS 不仅需要看价格，更要综合考虑网络质量、稳定性和售后服务。尤其是一些热门套餐的库存非常紧张，比如高质量的 CN2 GIA 等线路，因此及时获取库存信息非常重要。所以，我开发了一款基于 Node.js 的 VPS 库存监控工具，结合自定义 DSL 描述监控任务，使用 Puppeteer 实现自动化，并通过 Telegram 实时通知用户库存变化。

## 什么是自定义 DSL？

DSL（领域特定语言）是一种专门为某个特定领域或任务设计的编程语言。它通常具有简洁的语法和高度的抽象性，能够让用户更容易地描述和操作特定领域的问题。与通用编程语言相比，DSL 的目标是减少复杂性，提高效率，使得相关操作更加直观。

自定义 DSL 则是根据特定需求设计的 DSL，旨在满足用户的特定需求。例如，在 VPS 库存监控的场景下，我设计了一种自定义 DSL，使得用户可以以简单的、接近自然语言的方式定义监控任务。这种自定义 DSL 使得任务编写和配置更直观，降低了编程复杂性，特别适合不擅长编程的用户。

在 VPS 补货通知的场景中，使用自定义 DSL 可以让监控任务的编写变得非常简单。例如，用户可以直接描述要监控的页面以及要检查的库存状态，而无需编写复杂的代码。这样一来，监控任务不仅容易理解，而且便于维护，帮助用户更好地应对 VPS 库存变动。

## 项目概述

[vps-restock-notifier](https://github.com/harrisonwang/vps-restock-notifier) 是一个基于 Node.js 的 VPS 库存监控工具，结合自定义 DSL 描述监控任务，使用 Puppeteer 实现自动化，并通过 Telegram 实时通知用户库存变化。核心特性如下：

- 自定义 DSL 语法
- 基于 Puppeteer 的浏览器自动化
- Telegram 机器人通知
- 可配置的监控规则
- 多供应商支持

### DSL 的设计示例

以下代码用于检测 BandwagonHost 是否有库存：

```text
test "check bandwagonhost stock" {
    open "https://bandwagonhost.com/cart.php?a=add&pid=145"
    assert "stock" contains "Out of Stock"
}
```

这段 DSL 代码表示：打开特定的 URL，检查页面上 "stock" 字段是否显示“Out of Stock”，如果不显示则表示有库存，并发送 Telegram 通知。

### 如何实现自定义 DSL？

#### 1. 词法分析器

词法分析器（Lexer）负责将 DSL 代码解析成标记（token）。通过定义各类标记和正则表达式，将 DSL 代码转化为机器能理解的标记序列。

```js
class Lexer {
    constructor(sourceCode) {
        this.sourceCode = sourceCode;
        this.tokens = [];
        this.tokenSpec = [
            ['TEST', /test/],
            ['OPEN', /open/],
            ['ASSERT', /assert/],
            ['STRING', /"[^"]*"/],
            ['IDENTIFIER', /[a-zA-Z0-9_-]+/],
            ['CONTAINS', /contains/],
            ['LBRACE', /\{/],
            ['RBRACE', /\}/],
            ['WHITESPACE', /\s+/],
        ];
    }

    tokenize() {
        let input = this.sourceCode;
        while (input.length > 0) {
            let matched = false;
            for (let [type, regex] of this.tokenSpec) {
                const match = regex.exec(input);
                if (match && match.index === 0) {
                    if (type !== 'WHITESPACE') {
                        this.tokens.push({ type, value: match[0] });
                    }
                    input = input.slice(match[0].length);
                    matched = true;
                    break;
                }
            }
            if (!matched) throw new Error(`Unexpected token: ${input[0]}`);
        }
        return this.tokens;
    }
}
```

#### 2. 语法分析器

语法分析器（Parser）进一步处理标记，生成抽象语法树（AST），以便在浏览器自动化阶段使用。它解析测试块、页面操作等内容，建立任务的执行流程。

```js
class Parser {
    constructor(tokens) {
        this.tokens = tokens;
        this.pos = 0;
        this.currentToken = this.tokens[this.pos];
    }

    parseTest() {
        this.eat('TEST');
        const testName = this.parseString();
        this.eat('LBRACE');
        const actions = this.parseAction();
        return { testName, actions };
    }

    parseAction() {
        // 解析具体操作
    }
}
```

#### 3. 浏览器自动化与 Puppeteer

为了模拟真实用户的浏览器操作，我使用 Puppeteer 自动打开页面并执行点击、输入等操作。这样能够避免被识别为机器行为，提高监控的准确性。

```js
async run() {
    const browser = await puppeteer.launch({ args: ['--no-sandbox'] });
    const page = await browser.newPage();
    for (const test of this.tests) {
        for (const action of test.actions) {
            if (action.type === 'open') {
                await page.goto(action.url);
            } else if (action.type === 'assert') {
                const text = await page.$eval(action.selector, el => el.innerText);
                if (!text.includes(action.expected)) {
                    await telegramService.sendMessage(`${action.url} 有库存`);
                }
            }
        }
    }
    await browser.close();
}
```

通过这种方式，工具能够定期访问 VPS 库存页面，在发现有库存时自动通知用户。

#### 4. 实时通知集成：Telegram Bot

为了第一时间收到库存通知，我集成了 Telegram Bot。借助 node-telegram-bot-api 库，消息会直接推送至用户的 Telegram 上。

```js
import TelegramBot from 'node-telegram-bot-api';
class TelegramService {
    constructor() {
        this.bot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: false });
    }

    async sendMessage(message) {
        try {
            await this.bot.sendMessage(process.env.TELEGRAM_CHAT_ID, message, { parse_mode: 'HTML' });
        } catch (error) {
            console.error('发送通知失败:', error);
        }
    }
}
```

这样设置后，能确保在第一时间监控到库存变化信息，不再错过关键的库存补货信息。

### 快速上手

1. 克隆仓库

    ```bash
    git clone https://github.com/harrisonwang/vps-restock-notifier.git
    cd vps-restock-notifier
    ```

2. 安装依赖

    ```bash
    npm install
    ```

3. 配置环境变量

    ```bash
    cp .env.example .env
    # 编辑 .env 文件，填入您的 Telegram bot token 和 chat ID
    vim .env
    ```

4. 编写监控规则

    ```text
    test "check bandwagonhost stock" {
        open "https://bandwagonhost.com/cart.php?a=add&pid=145"
        assert "stock" contains "Out of Stock"
    }
    ```

5. 启动监控

    ```bash
    $ npm start

    > vps-restock-notifier@1.0.0 start
    > node src/index.js
    
    [11/3/2024, 12:32:01 PM] 开始检查库存...
    Running test: Check BWH CN2 GIA Stock
    Opening URL: https://bandwagonhost.com/cart.php?a=add&pid=145
    等待3秒...
    bandwagonhost.com 库存状态文本: Out of Stock
    bandwagonhost.com 暂无库存
    Running test: Check DMIT CN2 GIA Stock
    Opening URL: https://www.dmit.io/cart.php?a=add&pid=183
    等待3秒...
    dmit.io 库存状态文本: Out of Stock
    dmit.io 暂无库存
    [11/3/2024, 12:32:10 PM] 库存检查完成
    ==================================================
    ```

## 总结

通过 [vps-restock-notifier](https://github.com/harrisonwang/vps-restock-notifier) 项目，我展示了如何使用自定义 DSL 快速构建 VPS 库存监控工具。DSL 的设计使得任务编写和配置更直观，降低了编程复杂性。如果你对 [vps-restock-notifier](https://github.com/harrisonwang/vps-restock-notifier) 项目有兴趣，欢迎访问 GitHub 仓库并提出反馈或改进意见。

## 相关链接

[GitHub 仓库](https://github.com/harrisonwang/vps-restock-notifier)
[问题反馈](https://github.com/harrisonwang/vps-restock-notifier/issues)
