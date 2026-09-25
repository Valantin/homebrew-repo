cask "apache-directory-studio-git" do
  arch arm: "aarch64", intel: "x86_64"

  version :latest
  sha256 :no_check

  url "https://github.com/apache/directory-studio/archive/refs/heads/master.tar.gz"
  name "Apache Directory Studio"
  desc "Eclipse-based LDAP browser and directory client built from source"
  homepage "https://directory.apache.org/studio/"

  depends_on cask: "temurin@17"
  depends_on formula: "maven"
  depends_on :macos

  app "directory-studio-master/product/target/products/org.apache.directory.studio.product/macosx/cocoa/#{arch}/ApacheDirectoryStudio.app"

  preflight_steps do
    run "/usr/bin/env",
      args:           [
        "JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
        "MAVEN_OPTS=-Xmx1g -Duser.home={{temp}}/apache-directory-studio-home",
        "{{HOMEBREW_PREFIX}}/opt/maven/bin/mvn",
        "-Dmaven.repo.local={{temp}}/apache-directory-studio-m2",
        "-f",
        "pom-first.xml",
        "clean",
        "install",
      ],
      chdir:          "directory-studio-master",
      network_access: true,
      print_stdout:   true

    run "/usr/bin/env",
      args:           [
        "JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
        "MAVEN_OPTS=-Xmx1g -Duser.home={{temp}}/apache-directory-studio-home",
        "{{HOMEBREW_PREFIX}}/opt/maven/bin/mvn",
        "-Dmaven.repo.local={{temp}}/apache-directory-studio-m2",
        "clean",
        "install",
      ],
      chdir:          "directory-studio-master",
      network_access: true,
      print_stdout:   true
  end

  caveats <<~EOS
    This cask compiles the current master branch from source during installation.
    Reinstall it to rebuild from a newer commit:

      brew reinstall --cask --no-quarantine apache-directory-studio-source
  EOS
end

