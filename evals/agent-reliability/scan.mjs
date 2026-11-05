// Read-only local-history scan. Never reads authentication tables or executes transcripts.
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

const [dataDir, outputDir, excludeThread] = process.argv.slice(2);
if (!dataDir || !outputDir || !excludeThread) {
  console.error('Usage: node scan.mjs T3_USERDATA OUTPUT_DIR AUDIT_THREAD_ID');
  process.exit(2);
}
fs.mkdirSync(outputDir, { recursive: true });
const db = new DatabaseSync(path.join(dataDir, 'statev2.sqlite'), { readOnly: true });
db.exec('BEGIN');
const threads = db.prepare('SELECT * FROM orchestration_v2_projection_threads').all();
const items = db.prepare('SELECT * FROM orchestration_v2_projection_turn_items ORDER BY thread_id, ordinal').all();
db.exec('COMMIT');
db.close();
const legacy = new DatabaseSync(path.join(dataDir, 'state.sqlite'), { readOnly: true });
const activities = legacy.prepare('SELECT * FROM projection_thread_activities ORDER BY created_at, activity_id').all();
legacy.close();
const stringify = x => typeof x === 'string' ? x : JSON.stringify(x) ?? '';
const hash = x => createHash('sha256').update(x).digest('hex');
const redact = x => x.replace(/(?:Bearer\s+|AGE-SECRET-KEY-)[\w/+%.=-]+/gi, '[REDACTED]')
  .replace(/((?:token|password|secret|api[_-]?key)\s*[:=]\s*)[^\s,;]+/gi, '$1[REDACTED]')
  .replace(/[A-Za-z0-9_+/=-]{45,}/g, '[LONG_VALUE_REDACTED]');
const signal = /(?:command not found|Kommando nicht gefunden|No such file|Datei oder Verzeichnis nicht gefunden|error:|Error:|failed|fehlgeschlagen|usage limit|not installed|not support|infinite recursion|Exit code [1-9])/i;
const excerpt = x => redact(stringify(x).split('\n').filter(l => signal.test(l)).slice(0,3).join('\n').slice(0,600));
const category = text => {
  if (/usage limit|rate.limit|session limit|authenticate|not logged in|not support.*model|runtime stream|conversation found|PermissionMode|API errors/i.test(text)) return 'provider_or_quota';
  if (/sign.*fail|gpg:|pinentry|card error|Kartenfehler/i.test(text)) return 'signing';
  if (/command not found|Kommando nicht gefunden|not installed|missing libraries|FileNotFoundError.*t3/i.test(text)) return 'missing_tool_or_environment';
  if (/attribute .*missing|does not provide attribute|infinite recursion|option .*removed|alias has been removed/i.test(text)) return 'nix_evaluation';
  if (/No such file|Datei oder Verzeichnis nicht gefunden|ENOENT|no coredumps|nothing to commit/i.test(text)) return 'missing_path_or_expected_absence';
  if (/LaTeX Error|Fatal error occurred|Latexmk: Errors/i.test(text)) return 'document_build';
  if (/Found \d+ matches|replace_all/i.test(text)) return 'ambiguous_edit_anchor';
  if (/SyntaxError|ReferenceError|Syntaxfehler/i.test(text)) return 'script_or_quoting';
  if (/rebase|staged changes/i.test(text)) return 'git_state';
  return 'needs_context';
};
const failures = [], candidates = [];
const add = (source, threadId, sourceId, type, p, failed, position, raw) => {
  if (threadId === excludeThread) return;
  const d = p.data ?? {};
  const input = p.input ?? d.input ?? d.item?.command;
  const output = p.output ?? d.result?.content ?? d.item?.aggregatedOutput ?? p.diffStr ?? p.failure?.message ?? p.message ?? p.error ?? p.detail ?? '';
  const text = stringify(output);
  const record = { source, threadId, sourceId, position, type, category: category(text),
    classification: 'recorded_failure_requires_context', evidence: excerpt(output) || 'No diagnostic error line captured; inspect the referenced record in context.',
    toolCallId:p.nativeItemRef?.nativeId ?? p.toolCallId ?? null, taskId:p.taskId ?? null,
    exitCode:p.exitCode ?? d.item?.exitCode ?? null,
    payloadSha256: hash(raw) };
  if (failed) failures.push(record);
  else if (signal.test(text) && /tool|command|task/.test(type)) candidates.push({...record, classification:'embedded_failure_signal'});
  if (p.text && /^(user_message|assistant_message)$/.test(type) && !/^The following is the Codex agent history/.test(p.text)) {
    if (/still|wrong|falsch|instead|my.*mistake|mein.*fehler|lag.*falsch|du sollst|zu pauschal|does not work|not work|funktioniert nicht|unsupported|nicht.*unterstützt/i.test(p.text)) {
      candidates.push({...record, category:'behavioral_correction_signal', classification:'candidate_not_confirmed', evidence:redact(p.text.split('\n').filter(l=>/still|wrong|falsch|mistake|fehler|du sollst|zu pauschal|not work|nicht.*unterstützt/i.test(l)).join('\n').slice(0,500))});
    }
  }
};
for (const r of items) add('v2',r.thread_id,r.turn_item_id,r.type,JSON.parse(r.payload_json),r.status==='failed',r.ordinal,r.payload_json);
// Keep terminal tools and runtime failures. Task notifications are separate signals,
// not additional unique tool failures; started/updated copies are excluded.
for (const r of activities) {
  const p = JSON.parse(r.payload_json);
  if (!['tool.completed','task.completed','runtime.error','provider.turn.start.failed','runtime.warning'].includes(r.kind)) continue;
  const failed = p.status==='failed' || p.data?.result?.is_error===true || r.tone==='error';
  add('legacy',r.thread_id,r.activity_id,r.kind,p,failed,null,r.payload_json);
}
// Match a background-task notification to its terminal tool where an exact
// task ID or command title is present. Retain unmatched notifications honestly.
for (const f of failures.filter(f=>f.source==='legacy'&&f.type==='task.completed')) {
  const event=activities.find(a=>a.activity_id===f.sourceId), task=JSON.parse(event.payload_json);
  const tool=activities.find(a=>{
    if(a.thread_id!==f.threadId||a.kind!=='tool.completed')return false;
    const p=JSON.parse(a.payload_json),d=p.data??{};
    return (task.toolUseId && task.toolUseId===p.toolCallId) ||
      (task.title && [d.input?.command,d.input?.description,d.item?.command].includes(task.title));
  });
  if(tool) f.duplicateOf=tool.activity_id;
}
const inventory = threads.map(t=>{
  const own = items.filter(i=>i.thread_id===t.thread_id), old = activities.filter(i=>i.thread_id===t.thread_id);
  return {threadId:t.thread_id,projectId:t.project_id,deleted:!!t.deleted_at,excluded:t.thread_id===excludeThread,
    itemCount:own.length,messageCount:own.filter(i=>/^(user|assistant)_message$/.test(i.type)).length,
    toolItemCount:own.filter(i=>/command|dynamic_tool|file_change|web_search/.test(i.type)).length,
    legacyActivityCount:old.length,failureRecordCount:failures.filter(f=>f.threadId===t.thread_id).length,
    candidateCount:candidates.filter(f=>f.threadId===t.thread_id).length,
    review:'automated full scan; selected incidents reviewed in context; no signal is not proof of no error'};
});
const write = (name,data) => fs.writeFileSync(path.join(outputDir,name), data.map(x=>JSON.stringify(x)).join('\n')+'\n');
write('inventory.jsonl',inventory);write('failure-ledger.jsonl',failures);write('candidates.jsonl',candidates);
const counts = {capturedAt:new Date().toISOString(),excludedThread:excludeThread,threads:threads.length,
  listedNondeleted:threads.filter(t=>!t.deleted_at).length,deletedLocalRecords:threads.filter(t=>t.deleted_at).length,
  historicalItems:items.filter(i=>i.thread_id!==excludeThread).length,legacyActivityRows:activities.length,
  failureRecords:failures.length,v2Failures:failures.filter(f=>f.source==='v2').length,
  legacyToolFailures:failures.filter(f=>f.source==='legacy'&&f.type==='tool.completed').length,
  legacyTaskAndRuntimeFailures:failures.filter(f=>f.source==='legacy'&&f.type!=='tool.completed').length,
  duplicateTaskNotifications:failures.filter(f=>f.duplicateOf).length,
  candidateSignals:candidates.length,categories:Object.fromEntries([...new Set(failures.map(f=>f.category))].map(c=>[c,failures.filter(f=>f.category===c).length]))};
fs.writeFileSync(path.join(outputDir,'coverage.json'),JSON.stringify(counts,null,2)+'\n');
console.log(JSON.stringify(counts,null,2));
