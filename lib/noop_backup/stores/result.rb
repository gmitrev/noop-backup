module NoopBackup::Stores
  Result = Struct.new(:success, :error, :store, :key, :bytes, :duration, keyword_init: true) do
    def message
      if success
        "✅ [#{store}] back up successful — #{human_size(bytes)} in #{duration.round(1)}s → /#{key}"
      else
        "❌ [#{store}] Backup failed: #{error.message}"
      end
    end

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
end
