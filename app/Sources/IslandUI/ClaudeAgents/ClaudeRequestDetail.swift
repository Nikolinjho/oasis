import Foundation
import IslandCore
import SwiftUI

struct ClaudeRequestDetail: View {
  let panel: ClaudeAgentsPanel
  let request: ClaudeRequest
  let onAction: (ClaudeAgentsAction) -> Void

  private var active: Bool { request.phase == .waiting }
  private var draft: ClaudeReplyDraft { panel.drafts[request.id] ?? .init() }
  private var index: Int { min(draft.questionIndex, max(0, request.questions.count - 1)) }
  private var agentRequests: [ClaudeRequest] {
    panel.requests.filter { $0.id.agent == request.id.agent }.sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      requestPager
      if request.kind == .permission {
        permission
      } else if request.questions.indices.contains(index) {
        questions
      }
      if let error = panel.error {
        Text(error).font(.system(size: 10)).foregroundStyle(IslandPalette.dateAccent).lineLimit(2)
      }
      if !active {
        Text(phaseTitle).font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
          .accessibilityLabel(phaseTitle)
        if !panel.waiting.isEmpty {
          Button("Следующий ожидающий") { onAction(.nextWaiting) }.font(.system(size: 10))
            .buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var requestPager: some View {
    HStack(spacing: 8) {
      Text(request.kind == .permission ? "РАЗРЕШЕНИЕ" : "ВОПРОС")
        .font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(ClaudeAgentsStyle.accent)
      Spacer(minLength: 0)
      if agentRequests.count > 1, let current = agentRequests.firstIndex(where: { $0.id == request.id }) {
        Button {
          onAction(.selectRequest(agentRequests[max(0, current - 1)].id))
        } label: {
          Image(systemName: "chevron.left")
        }
        .disabled(current == 0)
        Text("Запрос \(current + 1)/\(agentRequests.count)").monospacedDigit()
        Button {
          onAction(.selectRequest(agentRequests[min(agentRequests.count - 1, current + 1)].id))
        } label: {
          Image(systemName: "chevron.right")
        }
        .disabled(current == agentRequests.count - 1)
      }
    }.font(.system(size: 9)).buttonStyle(.plain).foregroundStyle(IslandPalette.secondary)
  }

  private var questions: some View {
    let question = request.questions[index]
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(question.header.isEmpty ? "Claude спрашивает" : question.header)
          .font(.system(size: 11, weight: .medium)).foregroundStyle(IslandPalette.secondary)
        Spacer()
        if request.questions.count > 1 {
          Button {
            onAction(.selectQuestion(request.id, max(0, index - 1)))
          } label: {
            Image(systemName: "chevron.left")
          }
          .disabled(index == 0)
          Text("\(index + 1)/\(request.questions.count)").font(.system(size: 10)).foregroundStyle(IslandPalette.secondary)
          Button {
            onAction(.selectQuestion(request.id, min(request.questions.count - 1, index + 1)))
          } label: {
            Image(systemName: "chevron.right")
          }
          .disabled(index == request.questions.count - 1)
        }
      }.buttonStyle(.plain)
      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 5) {
          Text(question.text).font(.system(size: 13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
          ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
            optionRow(option, index: optionIndex, multi: question.multiSelect)
          }
        }
      }
      .frame(maxHeight: .infinity)
      HStack(spacing: 6) {
        Text("Свой ответ").font(.system(size: 10)).foregroundStyle(IslandPalette.tertiary)
        Spacer()
        if question.multiSelect { Text("Можно несколько").font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary) }
      }
      ClaudeReplyEditor(
        text: draft.texts[index] ?? "", position: draft.positions[index] ?? .init(), editable: active,
        onText: { onAction(.text(request.id, question: index, value: $0)) },
        onPosition: { onAction(.textPosition(request.id, question: index, position: $0)) },
        onFocus: { onAction(.beginEditing) }, onSubmit: { onAction(.send(request.id)) }, onEscape: { onAction(.close) }
      )
      .id("\(request.id.value)-\(index)")
      .padding(5).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.045)))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(IslandPalette.divider, lineWidth: 1))
      .frame(height: panel.compact ? 36 : 44)
      .accessibilityLabel("Свой ответ Claude")
      HStack {
        Text("Enter – новая строка").font(.system(size: 9)).foregroundStyle(IslandPalette.tertiary)
        Spacer()
        Button(request.phase == .sending ? "Отправляется…" : "Ответить ⌘↩") { onAction(.send(request.id)) }
          .font(.system(size: 11)).buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
          .disabled(!active || draft.answer(for: request) == nil)
          .keyboardShortcut(.return, modifiers: .command)
          .accessibilityLabel("Ответить Claude")
      }
    }
  }

  private func optionRow(_ option: ClaudeQuestion.Option, index optionIndex: Int, multi: Bool) -> some View {
    let selected = draft.options[index, default: []].contains(optionIndex)
    return Button {
      onAction(.toggleOption(request.id, question: index, option: optionIndex))
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: selected ? (multi ? "checkmark.square.fill" : "largecircle.fill.circle") : (multi ? "square" : "circle"))
          .font(.system(size: 12)).foregroundStyle(selected ? ClaudeAgentsStyle.accent : IslandPalette.tertiary)
          .padding(.top, 2)
        VStack(alignment: .leading, spacing: 2) {
          Text(option.label).font(.system(size: 11, weight: .medium)).foregroundStyle(IslandPalette.foreground)
          if !option.description.isEmpty { Text(option.description).font(.system(size: 10)).foregroundStyle(IslandPalette.secondary) }
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 3).contentShape(Rectangle())
    }
    .buttonStyle(.plain).disabled(!active)
    .accessibilityLabel(option.label).accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var permission: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(request.toolName).font(.system(size: 15, weight: .semibold))
      Text("Разрешить это действие один раз?").font(.system(size: 12)).foregroundStyle(IslandPalette.secondary)
      ScrollView(.vertical, showsIndicators: false) {
        Text(permissionPreview ?? "Подробности недоступны. Продолжи в Claude Code.").font(.system(size: 10, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.035)))
      Spacer(minLength: 0)
      HStack(spacing: 16) {
        Button("Разрешить один раз") { onAction(.allowOnce(request.id)) }
          .buttonStyle(SoonTextButtonStyle(tint: ClaudeAgentsStyle.accent))
          .accessibilityLabel("Разрешить один раз")
          .disabled(permissionPreview == nil)
        Button("Отклонить") { onAction(.deny(request.id)) }
          .buttonStyle(SoonTextButtonStyle(tint: IslandPalette.dateAccent))
          .accessibilityLabel("Отклонить действие Claude")
      }.font(.system(size: 11)).disabled(!active)
    }
  }

  private var permissionPreview: String? {
    guard let object = try? JSONSerialization.jsonObject(with: request.originalInput) as? [String: Any],
      let input = object["tool_input"],
      let data = try? JSONSerialization.data(withJSONObject: input, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
      let string = String(data: data, encoding: .utf8)
    else { return nil }
    return string
  }

  private var phaseTitle: String {
    switch request.phase {
    case .waiting: "Ожидает ответа"
    case .sending: "Ответ отправляется…"
    case .accepted: "Ответ передан Claude Code"
    case .continued: "Claude продолжил работу"
    case .declined: "Действие отклонено"
    case .expired: "Время ожидания истекло. Продолжи в Claude Code."
    case .cancelled: "Запрос отменён"
    case .disconnected: "Связь с запросом потеряна. Продолжи в Claude Code."
    }
  }
}
