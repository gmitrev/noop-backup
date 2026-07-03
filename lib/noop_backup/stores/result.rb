module NoopBackup::Stores
  Result = Struct.new(:success, :error, :store, :key, :bytes, :duration, keyword_init: true) do
    def message
      if success
        "✅ [#{store}] Backup successful — #{NoopBackup.utils.human_size(bytes)} in #{duration.round(1)}s → /#{key}"
      else
        "❌ [#{store}] Backup failed: #{error.message}"
      end
    end
  end
end
