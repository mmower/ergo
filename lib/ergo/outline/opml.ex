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

  def opml_event_name(:error), do: "ERROR"
  def opml_event_name(event), do: to_string(event)

  def opml_event_pos(line, col), do: "#{line}:#{col}"

  def opml_event_input(input) do
    input
    |> Ergo.Utils.ellipsize()
    |> to_xml_attr_value()
  end

  def opml_event_match(match), do: to_xml_attr_value(match)

  def opml_event_info(info) when not is_binary(info), do: to_xml_attr_value(inspect(info))
  def opml_event_info(info), do: to_xml_attr_value(info)

  def opml_event_text(parser, label) do
    to_string(parser) <> "/" <> to_string(label) |> to_xml_attr_value()
  end

  def opml_event_tagend(true), do: "\">\n"
  def opml_event_tagend(false), do: "\" />\n"

  def generate_opml_node(depth, event, parser, label, line, col, input, match, info, open_tag) do
    String.duplicate("  ", depth) <>
    "<outline event=\"" <>
    opml_event_name(event) <>
    "\" pos=\"" <>
    opml_event_pos(line, col) <>
    "\" input=\"" <>
    opml_event_input(input) <>
    "\" match=\"" <>
    opml_event_match(match) <>
    "\" info=\"" <>
    opml_event_info(info) <>
    "\" text=\"" <>
    opml_event_text(parser, label) <>
    opml_event_tagend(open_tag)
  end

  def generate_node(%{event: :enter, type: parser, label: label, line: line, col: col, depth: depth, input: input}, :open) do
    generate_opml_node(depth, :enter, parser, label, line, col, input, "", "", true)
  end

  def generate_node(%{event: :enter, type: parser, label: label, line: line, col: col, depth: depth, input: input}, :closed) do
    generate_opml_node(depth, :enter, parser, label, line, col, input, "", "", false)
  end

  def generate_node(%{event: :match, type: parser, label: label, line: line, col: col, depth: depth, ast: nil}, _) do
    generate_opml_node(depth, :match, parser, label, line, col, "", "*ignore*", "", false)
  end

  def generate_node(%{event: :match, type: parser, label: label, line: line, col: col, depth: depth, ast: ast}, _) do
    generate_opml_node(depth, :match, parser, label, line, col, "", "#{Ergo.Utils.typeof(ast)}: #{inspect(ast)}", "", false)
  end

  def generate_node(%{event: :error, type: parser, label: label, line: line, col: col, depth: depth, errors: errors}, _) do
    try do
      generate_opml_node(depth, :error, parser, label, line, col, "", "", errors, false)
    catch
      :exit, _ -> "not really"
    end
  end

  def generate_node(%{event: :leave, type: parser, label: label, line: line, col: col, depth: depth}, _) do
    generate_opml_node(depth, :leave, parser, label, line, col, "", "", "", false)
  end

  def generate_node(%{event: :event, user_event: event, details: details, type: parser, label: label, line: line, col: col, depth: depth}, _) do
    try do
      generate_opml_node(depth, event, parser, label, line, col, "", "", details, false)
    catch
      :exit, _ -> "not really"
    end
  end

  def generate_node(%{depth: depth}, :close) do
    [String.duplicate("  ", depth), "</outline>\n"]
  end

  def to_xml_attr_value(message) do
    message
    # |> String.replace(<<10::utf8>>, "\\n") # CR turns into space
    # |> String.replace(<<13::utf8>>, "\\r") # LF turns into space
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
