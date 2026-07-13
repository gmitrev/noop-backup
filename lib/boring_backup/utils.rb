module BoringBackup::Utils
  extend self

  def human_size(bytes)
    units = %w[B KB MB GB TB]
    size = bytes.to_f
    i = 0
    while size >= 1024 && i < units.size - 1
      size /= 1024
      i += 1
    end
    format("%.1f %s", size, units[i])
  end
end
