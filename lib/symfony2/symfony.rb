namespace :symfony do
  desc "Runs custom symfony command"
  task :default, :roles => :app, :except => { :no_release => true } do
    prompt_with_default(:task_arguments, "cache:clear")

    stream "cd #{latest_release} && #{php_bin} #{symfony_console} #{task_arguments} --env=#{symfony_env_prod}"
  end

  namespace :logs do
    [:tail, :tail_dev].each do |action|
      lines = ENV['lines'].nil? ? '50' : ENV['lines']
      log   = action.to_s == 'tail' ? 'prod.log' : 'dev.log'
      desc "Tail #{log}"
      task action, :roles => :app, :except => { :no_release => true } do
        run "#{try_sudo} tail -n #{lines} -f #{shared_path}/#{log_path}/#{log}" do |channel, stream, data|
          trap("INT") { puts 'Interupted'; exit 0; }
          puts
          puts "#{channel[:host]}: #{data}"
          break if stream == :err
        end
      end
    end
  end

  namespace :assets do
    desc "Updates assets version (in config.yml)"
    task :update_version, :roles => :app, :except => { :no_release => true } do
       run "#{try_sudo} sed -i 's/\\(assets_version: \\)\\(.*\\)$/\\1 #{real_revision}/g' #{latest_release}/#{app_path}/config/config.yml"
    end

    desc "Installs bundle's assets"
    task :install, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Installing bundle's assets"

      install_options = ''

      if true == assets_symlinks then
          install_options += " --symlink"
      end

      if true == assets_relative then
          install_options += " --relative"
      end

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} assets:install #{web_path} #{install_options} --env=#{symfony_env_prod}'"
      puts_ok
    end
  end

  namespace :assetic do
    desc "Dumps all assets to the filesystem"
    task :dump, :roles => :app,  :except => { :no_release => true } do
      pretty_print "--> Dumping all assets to the filesystem"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} assetic:dump --env=#{symfony_env_prod} --no-debug'"
      puts_ok
    end
  end

  namespace :vendors do
    desc "Runs the bin/vendors script to install the vendors (fast if already installed)"
    task :install, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Installing vendors"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_vendors} install'"
      puts_ok
    end

    desc "Runs the bin/vendors script to reinstall the vendors"
    task :reinstall, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Reinstalling vendors"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_vendors} install --reinstall'"
      puts_ok
    end

    desc "Runs the bin/vendors script to upgrade the vendors"
    task :upgrade, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Upgrading vendors"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_vendors} update'"
      puts_ok
    end
  end

  namespace :bootstrap do
    desc "Runs the bin/build_bootstrap script"
    task :build, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Building bootstrap file"

      if !remote_file_exists?("#{latest_release}/#{build_bootstrap}") && true == use_composer then
        set :build_bootstrap, "vendor/sensio/distribution-bundle/Sensio/Bundle/DistributionBundle/Resources/bin/build_bootstrap.php"
        run "#{try_sudo} sh -c 'cd #{latest_release} && test -f #{build_bootstrap} && #{php_bin} #{build_bootstrap} #{app_path} || echo '#{build_bootstrap} not found, skipped''"
      else
        run "#{try_sudo} sh -c 'cd #{latest_release} && test -f #{build_bootstrap} && #{php_bin} #{build_bootstrap} || echo '#{build_bootstrap} not found, skipped''"
      end

      puts_ok
    end
  end

  namespace :composer do
    desc "Gets composer and installs it"
    task :get, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Downloading Composer"
      if !remote_file_exists?("#{latest_release}/composer.phar")
        run "#{try_sudo} sh -c 'cd #{latest_release} && curl -s http://getcomposer.org/installer | #{php_bin}'"
      else
        run "#{try_sudo} cd #{latest_release} && #{php_bin} composer.phar self-update"
      end
      puts_ok
    end

    desc "Updates composer"
    task :update, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Updating Composer"
      try_sudo "#{composer_bin} self-update"
      puts_ok
    end

    desc "Runs composer to install vendors from composer.lock file"
    task :install, :roles => :app, :except => { :no_release => true } do
      if composer_bin
        symfony.composer.update
      else
        symfony.composer.get
        composer_bin = "#{php_bin} composer.phar"
      end

      pretty_print "--> Installing Composer dependencies"
      run "#{try_sudo} sh -c 'cd #{latest_release} && #{composer_bin} install #{composer_options}'"
      puts_ok
    end

    desc "Runs composer to update vendors, and composer.lock file"
    task :update, :roles => :app, :except => { :no_release => true } do
      if composer_bin
        symfony.composer.update
      else
        symfony.composer.get
        composer_bin = "#{php_bin} composer.phar"
      end

      pretty_print "--> Updating Composer dependencies"
      run "#{try_sudo} sh -c 'cd #{latest_release} && #{composer_bin} update #{composer_options}'"
      puts_ok
    end
  end

  namespace :cache do
    desc "Clears cache"
    task :clear, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Clearing cache"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} cache:clear --env=#{symfony_env_prod}'"
      run "#{try_sudo} chmod -R g+w #{latest_release}/#{cache_path}"
      puts_ok
    end

    desc "Warms up an empty cache"
    task :warmup, :roles => :app, :except => { :no_release => true } do
      pretty_print "--> Warming up cache"

      run "#{try_sudo} sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} cache:warmup --env=#{symfony_env_prod}'"
      run "#{try_sudo} chmod -R g+w #{latest_release}/#{cache_path}"
      puts_ok
    end
  end

  namespace :project do
    desc "Clears all non production environment controllers"
    task :clear_controllers do
      pretty_print "--> Clear controllers"

      run "#{try_sudo} sh -c 'cd #{latest_release} && rm -f #{web_path}/app_*.php'"
      puts_ok
    end
  end
end
