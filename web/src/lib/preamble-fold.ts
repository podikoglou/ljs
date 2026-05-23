import {
  type EditorState,
  Facet,
  StateEffect,
  StateField,
  type Extension,
} from "@codemirror/state";
import { Decoration, type DecorationSet, EditorView, WidgetType } from "@codemirror/view";

const toggleEffect = StateEffect.define<void>();

const lineCountFacet = Facet.define<number, number>({
  combine: (values) => values[0] ?? 0,
});

class ToggleWidget extends WidgetType {
  lineCount: number;
  collapsed: boolean;

  constructor(lineCount: number, collapsed: boolean) {
    super();
    this.lineCount = lineCount;
    this.collapsed = collapsed;
  }

  toDOM(view: EditorView) {
    const span = document.createElement("span");
    span.textContent = this.collapsed
      ? `\u25B6 Preamble (${this.lineCount} lines)`
      : "\u25BC Hide preamble";
    span.className = "cm-preamble-toggle";
    span.setAttribute("role", "button");
    span.addEventListener("click", () => {
      view.dispatch({ effects: toggleEffect.of() });
    });
    return span;
  }

  eq(other: ToggleWidget) {
    return this.lineCount === other.lineCount && this.collapsed === other.collapsed;
  }

  ignoreEvent() {
    return false;
  }
}

function buildFold(state: EditorState): DecorationSet {
  const lineCount = state.facet(lineCountFacet);
  if (lineCount <= 0) return Decoration.none;

  const doc = state.doc;
  if (doc.lines < lineCount) return Decoration.none;

  const collapsed = state.field(collapsedField);

  if (collapsed) {
    const widget = Decoration.replace({
      widget: new ToggleWidget(lineCount, true),
    });
    return Decoration.set([widget.range(doc.line(1).from, doc.line(lineCount).to)]);
  }

  const pos = doc.lines > lineCount ? doc.line(lineCount + 1).from : doc.line(lineCount).to;
  return Decoration.set([
    Decoration.widget({ widget: new ToggleWidget(lineCount, false) }).range(pos),
  ]);
}

const collapsedField = StateField.define<boolean>({
  create: () => true,
  update: (val, tr) => {
    for (const e of tr.effects) {
      if (e.is(toggleEffect)) return !val;
    }
    return val;
  },
});

const foldField = StateField.define<DecorationSet>({
  create(state) {
    return buildFold(state);
  },
  update(_folded, tr) {
    return buildFold(tr.state);
  },
  provide: (f) => EditorView.decorations.from(f),
});

export function preambleFold(lineCount: number): Extension[] {
  return [lineCountFacet.of(lineCount), collapsedField, foldField];
}
