#!/bin/bash
# Claude Code Notification 훅 — Slack 알림 전송
# 발동 시점: Claude Code가 사용자 입력/권한을 요청할 때

# .env.local 로드: CLAUDE_PROJECT_DIR → 현재 디렉토리 순으로 탐색
if [ -f "$CLAUDE_PROJECT_DIR/.env.local" ]; then
    set -a && source "$CLAUDE_PROJECT_DIR/.env.local" && set +a
elif [ -f ".env.local" ]; then
    set -a && source ".env.local" && set +a
fi

INPUT=$(cat)

node -e "
const https = require('https');
const http = require('http');
const url = require('url');

const webhookUrl = process.env.SLACK_WEBHOOK_URL || '';
if (!webhookUrl) process.exit(0);

// stdin JSON 파싱
let message = 'Claude Code가 응답을 기다리고 있습니다.';
try {
  const raw = \`$INPUT\`.trim() || process.env._HOOK_INPUT || '{}';
  const d = JSON.parse(raw);
  message = d.message || message;
} catch {}

// 알림 유형 판별
// 권한 요청: 도구 실행 승인 관련 메시지
// 입력 대기: 작업 완료 후 사용자 응답 대기
const isPermission = /tool|permission|allow|bash|read|write|edit|실행|허용|권한/i.test(message);

const headerText = isPermission
  ? '🔐 Claude Code 권한 요청'
  : '💬 Claude Code 입력 대기';
const slackText = isPermission
  ? '🔐 *[Claude Code] 권한 요청*'
  : '💬 *[Claude Code] 입력 대기*';
const statusText = isPermission
  ? '권한 승인 필요'
  : '사용자 응답 대기';

// 프로젝트명
const path = require('path');
const fs = require('fs');
const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
let projectName = path.basename(projectDir);
try {
  const pkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf8'));
  projectName = pkg.name || projectName;
} catch {}

// 요청 시간 (2026-4-3 9시 55분 형식)
const now = new Date();
const parts = new Intl.DateTimeFormat('ko-KR', {
  timeZone: 'Asia/Seoul',
  year: 'numeric', month: 'numeric', day: 'numeric',
  hour: 'numeric', minute: '2-digit', hour12: false
}).formatToParts(now);
const get = (type) => (parts.find(p => p.type === type) || {}).value || '';
const requestTime = get('year') + '-' + get('month') + '-' + get('day') + ' ' + get('hour') + '시 ' + get('minute') + '분';

const payload = JSON.stringify({
  text: slackText,
  blocks: [
    {
      type: 'header',
      text: { type: 'plain_text', text: headerText, emoji: true }
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: '*프로젝트*\n' + projectName },
        { type: 'mrkdwn', text: '*상태*\n' + statusText }
      ]
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: '*요청 시간*\n' + requestTime },
        { type: 'mrkdwn', text: '*메시지*\n' + message }
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
