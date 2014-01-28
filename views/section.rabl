node :_response_info do
  { status: "ok" }
end

node(:title) { @section.title }
node(:link) { @section.link }
node(:description) { @section.description }
node(:hero) { @section.assets[:hero_image].file_url rescue nil }

child(@section.modules => "modules") do
  node(:title) { |m| m.title }
  node(:type) { |m| m.type }
  node :frame, :if => lambda { |m| m.type == "Frame" } do |m|
    m.frame
  end
  node :image, :if => lambda { |m| m.type == "Image" } do |m|
    m.assets[:image].file_url
  end
  node :text, :if => lambda { |m| m.type == "Text" } do |m|
    m.text
  end
  node :link, :if => lambda { |m| m.type == "Text" || m.type == "Image" } do |m|
    m.link
  end
  node :colour, :if => lambda { |m| m.type == "Text" } do |m|
    m.colour
  end
end