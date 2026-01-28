class FindInfoPlist
    def self.default_info_plist_path
        # Find first 'Info.plist' in the current working directory
        # ignoring any in 'build', or 'test' folders
        return Dir.glob("./{ios/,}*/Info.plist").reject{|path| path =~ /build|test/i }.sort.first
    end
end
