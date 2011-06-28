require 'bridge.rb'

task :start => ['src:setup', 'dest:setup', 'dest:start', 'bridge:setup']

namespace :src do
  task :setup do
    File.exists? '/tmp/src' and rm_r '/tmp/src'
    cp_r 'test/data/src', '/tmp'
    cd '/tmp/src' do
      sh "git init"
      sh "git add content"
      sh "git commit -m'first commit'"
    end
  end
end

namespace :dest do
  task :setup  do
    File.exists? '/tmp/dest' and rm_r '/tmp/dest'
    mkdir '/tmp/dest'
    cd '/tmp/dest' do
      sh "hg init"
    end
  end

  task :start do
    cd '/tmp/dest' do
      sh "hg serve --daemon --pid-file /tmp/dest.pid --accesslog /tmp/dest.log --errorlog /tmp/dest.err --config web.allow_push='*' --config web.push_ssl=false"
    end
  end

  task :stop do
    sh "kill `cat /tmp/dest.pid`"
    rm '/tmp/dest.pid'
  end
end

namespace :bridge do
  task :setup do
    Bridge.new.setup
  end

  task :run do
    Bridge.new.run
  end
end