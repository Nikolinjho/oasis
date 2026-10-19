const pending = new Map()

function supported(questions) {
  return Array.isArray(questions) && questions.length > 0 && questions.length <= 16 &&
    new Set(questions.map(q => q.question)).size === questions.length &&
    questions.every(q => typeof q.question === 'string' && q.question.length > 0 &&
      Array.isArray(q.options) && q.options.length > 0 && q.options.length <= 64 &&
      q.options.every(option => typeof option.label === 'string' && option.label.length > 0))
}

function candidateOf(line, questions) {
  const candidate = JSON.parse(line)
  if (typeof candidate.responseID !== 'string' || !candidate.answers ||
    Object.keys(candidate.answers).length !== questions.length ||
    !questions.every(q => typeof candidate.answers[q.question] === 'string' && candidate.answers[q.question].trim())) {
    throw new Error('Некорректный ответ Oasis')
  }
  return candidate
}

async function readCandidate(stream, questions) {
  let buffer = ''
  while (true) {
    const chunk = await stream.next()
    if (chunk.done) throw new Error('Oasis недоступен')
    if (chunk.value.stream !== 'stdout') continue
    buffer += chunk.value.text
    if (buffer.length > 1024 * 1024) throw new Error('Слишком большой ответ Oasis')
    const newline = buffer.indexOf('\n')
    if (newline !== -1) return candidateOf(buffer.slice(0, newline), questions)
  }
}

async function finish($, helper, question, outcome, responseID) {
  const result = await $.process.run([helper, 'question-finished'], {
    stdin: JSON.stringify({ question, outcome, ...(responseID ? { responseID } : {}) }),
    timeoutMs: 2000,
  })
  return result.exitCode === 0 && result.stdout.trim() === 'confirmed'
}

async function ask($, e, next, entry) {
  const terminal = next(e).then(result => ({ source: 'terminal', result }))
  let stream
  let candidate
  const oasis = (async () => {
    // Виджет подключается после появления штатного вопроса и прохождения чужих hooks.
    const questions = await entry.visible
    if (entry.finished || next.signal.aborted || !supported(questions)) return terminal
    const sessionID = await $.session.id()
    const question = { agent: { provider: 'claude-code', sessionID, ...(e.agentId ? { agentID: e.agentId } : {}) }, toolUseID: e.tool_use_id }
    const helper = $.plugin.root + '/OasisClaudeBridge'
    stream = $.process.spawn({ argv: [helper, 'question'], input: JSON.stringify({
      session_id: sessionID, ...(e.agentId ? { agent_id: e.agentId } : {}),
      hook_event_name: 'PreToolUse', tool_name: 'AskUserQuestion', tool_use_id: e.tool_use_id,
      cwd: await $.session.cwd(), tool_input: { questions },
    }) })
    candidate = await readCandidate(stream, questions)
    return { source: 'oasis', helper, question, candidate, questions }
  })().catch(() => terminal)
  try {
    const winner = await Promise.race([terminal, oasis])
    entry.finished = true
    if (winner.source === 'oasis') {
      if (await finish($, winner.helper, winner.question, 'oasis', winner.candidate.responseID)) {
        entry.finishedInOasis = true
        return { result: { questions: winner.questions, answers: winner.candidate.answers, annotations: {} } }
      }
      return (await terminal).result
    }
    return winner.result
  } finally {
    entry.finished = true
    entry.show()
    // Завершение по identity закрывает также запрос, зарегистрировавшийся после ответа терминала.
    if (!entry.finishedInOasis) {
      const sessionID = await $.session.id()
      const question = { agent: { provider: 'claude-code', sessionID, ...(e.agentId ? { agentID: e.agentId } : {}) }, toolUseID: e.tool_use_id }
      await finish($, $.plugin.root + '/OasisClaudeBridge', question, next.signal.aborted ? 'cancelled' : 'terminal').catch(() => {})
    }
    if (stream) await stream.return().catch(() => {})
  }
}

export function register(on) {
  on('ui.render', { component: 'AskUserQuestion' }, async ($, e, next) => {
    pending.get(e.requestId)?.show(e.props.questions)
    return next(e)
  })
  on('tool.call', { tool: 'AskUserQuestion' }, async ($, e, next) => {
    if (!e.tool_use_id || !supported(e.questions)) return next(e)
    let show
    const visible = new Promise(resolve => { show = resolve })
    const entry = { visible, show, finished: false, finishedInOasis: false }
    pending.set(e.tool_use_id, entry)
    try { return await ask($, e, next, entry) }
    finally { pending.delete(e.tool_use_id) }
  })
}
