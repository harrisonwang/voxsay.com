# _plugins/copy_markdown_hook.rb

require 'fileutils'

Jekyll::Hooks.register :posts, :post_write do |post|
  # 目标 Markdown 文件的路径
  # 将 .html 或 /index.html 替换为 .md
  dest_path = post.destination(post.site.dest)
  markdown_dest_path = dest_path.sub(/\.html$/, '.md')

  # 源 Markdown 文件的路径
  source_path = post.path

  # 确保目标目录存在
  dest_dir = File.dirname(markdown_dest_path)
  FileUtils.mkdir_p(dest_dir)

  # 复制文件
  FileUtils.cp(source_path, markdown_dest_path)
  # Jekyll.logger.info "Copied markdown for #{post.id}"
end
