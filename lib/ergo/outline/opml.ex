defmodule Ergo.Outline.OPML do
  alias Ergo.Outline.Builder
  require IEx

  def generate_opml(id, events) do
    outline =
      events
      |> Builder.build_from_events()
      |> Builder.walk(&generate_node/2)

    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<opml version=\"2.0\">", "<head>\n", "</head>\n", "<body>\n<outline text=\"#{id}\">\n", outline, "</outline>\n</body>\n</opml>\n"]
  end

  def generate_node(%{event: :enter, type: parser, label: label, line: line, col: col, depth: depth, input: input}, :open) do
    [String.duplicate("  ", depth), "<outline event=\"enter\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(input), "\">\n"]
  end

  def generate_node(%{event: :enter, type: parser, label: label, line: line, col: col, depth: depth, input: input}, :closed) do
    [String.duplicate("  ", depth), "<outline event=\"enter\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(input), "\" />\n"]
  end

  def generate_node(%{event: :match, type: parser, label: label, line: line, col: col, depth: depth, ast: ast}, _) do
    match = if is_nil(ast) do
      "NIL-IGNORE"
    else
      "#{Ergo.Utils.typeof(ast)}: #{inspect(ast)}"
    end

    [String.duplicate("  ", depth), "<outline event=\"match\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(match), "\" />\n"]
  end

  def generate_node(%{event: :error, type: parser, label: label, line: line, col: col, depth: depth, errors: errors}, _) do
    [String.duplicate("  ", depth), "<outline event=\"ERROR\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(inspect(errors)), "\" />\n"]
  end

  def generate_node(%{event: :leave, type: parser, label: label, line: line, col: col, depth: depth}, _) do
    [String.duplicate("  ", depth), "<outline event=\"leave\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"\" />\n"]
  end

  def generate_node(%{event: :event, user_event: event, details: details, type: parser, label: label, line: line, col: col, depth: depth}, _) do
    [String.duplicate("  ", depth), "<outline event=\"", to_string(event), "\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(inspect(details)), "\" />\n"]
  end

  def generate_node(%{depth: depth}, :close) do
    [String.duplicate("  ", depth), "</outline>\n"]
  end

  def to_xml_attr_value(message) do
    message
    |> String.replace(~r/&/, "&amp;")
    |> String.replace(~r/"/, "&quot;")
    |> String.replace(~r/</, "&lt;")
    |> String.replace(~r/>/, "&gt;")
    |> String.replace(~r/\r/, "\\r")
    |> String.replace(~r/\n/, "\\n")
    |> String.replace(~r/\t/, "\\t")
    |> String.replace(~r/\v/, "\\v")
  end

end
