#!/bin/bash
# Claude Code Stop 훅 — 작업 완료 Slack 알림
# 발동 시점: 에이전트가 작업을 마치고 멈출 때

# .env.local 로드: CLAUDE_PROJECT_DIR → 현재 디렉토리 순으로 탐색
if [ -f "$CLAUDE_PROJECT_DIR/.env.local" ]; then
    set -a && source "$CLAUDE_PROJECT_DIR/.env.local" && set +a
elif [ -f ".env.local" ]; then
    set -a && source ".env.local" && set +a
fi

node -e "
const https = require('https');
const http = require('http');
const url = require('url');

const webhookUrl = process.env.SLACK_WEBHOOK_URL || '';
if (!webhookUrl) process.exit(0);

// 프로젝트명
const path = require('path');
const fs = require('fs');
const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
let projectName = path.basename(projectDir);
try {
  const pkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf8'));
  projectName = pkg.name || projectName;
} catch {}

// 완료 시간 (2026-4-3 9시 55분 형식)
const now = new Date();
const parts = new Intl.DateTimeFormat('ko-KR', {
  timeZone: 'Asia/Seoul',
  year: 'numeric', month: 'numeric', day: 'numeric',
  hour: 'numeric', minute: '2-digit', hour12: false
}).formatToParts(now);
const get = (type) => (parts.find(p => p.type === type) || {}).value || '';
const completedTime = get('year') + '-' + get('month') + '-' + get('day') + ' ' + get('hour') + '시 ' + get('minute') + '분';

const payload = JSON.stringify({
  text: '✅ *[Claude Code] 작업 완료*',
  blocks: [
    {
      type: 'header',
      text: { type: 'plain_text', text: '✅ Claude Code 작업 완료', emoji: true }
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: '*프로젝트*\n' + projectName },
        { type: 'mrkdwn', text: '*상태*\n작업 완료' }
      ]
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: '*완료 시간*\n' + completedTime },
        { type: 'mrkdwn', text: '*메시지*\n작업이 모두 완료되었습니다. 확인해주세요.' }
      ]
    }
  ]
});

const parsed = new url.URL(webhookUrl);
const lib = parsed.protocol === 'https:' ? https : http;
const options = {
  hostname: parsed.hostname,
  path: parsed.pathname,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload, 'utf8')
  }
};

const req = lib.request(options, (res) => { res.resume(); });
req.on('error', (e) => process.stderr.write('Slack 전송 실패: ' + e.message + '\n'));
req.write(payload, 'utf8');
req.end();
"

exit 0
