<h3>tumbleweed</h3>

<p>You have landed on tumbleweed's public github repository. This document is for helping new developers get started with tumbleweed.</p>

<h4>A look at tumbleweed's dependencies</h4>
<p>As a convienience, and to make development easier across different platforms, this tumbleweed repository uses a <a href='https://www.virtualbox.org/'>virtual box</a> running <a href='http://www.vagrantup.com'>vagrant</a> to simulate a Linux 32-bit environment. If you do not have these installed already you may or may not have to get them to contribute to this project.</p>

<p>tumbleweed is currently running on node.js and is currently a node application. Therefore, you may have to install node.js</p>

<h4>Getting started</h4>

<ol>
<li><h5>cloning the repo to local</h5></li>
<ol>
 <li>Unless you have a github desktop application, you will be likely have to use command line <a href='http://git-scm.com/'>git</a> commands. To clone the repository to a local directory, execute:
 <pre>git clone https://github.com/mikesteele/tumbleweed.git /this/local/directory/</pre></li>

</ol>
<li><h5>run and access Vagrant machine</h5> execute:
<pre>vagrant up;
vagrant ssh;</pre>
to set up and access the virtual machine.
<li><h5>installing node.js</h5>
<pre>sudo apt-get update;
sudo apt-get install software-properties-common python-software-properties;
sudo add-apt-repository ppa:chris-lea/node.js;
sudo apt-get update;
sudo apt-get install nodejs;
</pre>
 in the app directory to get the reccomended version of node.js. You should now be able to execute:
<pre>node -v;
npm -v;</pre>
after completing this step.</li>

<li><h5>installing node dependencies</h5>
execute: <pre>cd ../../vagrant;
sudo npm install;</pre>
 in the repo directory to log in to the virtual machine and install node required packages</li>
<li><h5>running the app server</h5>
Finally, execute:
<pre>node app.js</pre>
 to run the tumbleweed app server</li>
<li><h5>viewing the web app</h5>
visit:
<pre>localhost:8080</pre>
 in any web browser to look at the site.</li>
</ol>

<h4>Using Git</h4>

<p>If you have a GitHub desktop application, much of this can be safely ignored, otherwise here is an overview of some basic Git commands you find useful.</p>

<ol>
<li><h5>pulling remote changes</h5>
To pull changes from the tumbleweed remote repository, execute:
<pre>git pull</pre>
</li>
 <li><h5>commiting local changes</h5>
 To commit your local changes use:</li>
 <pre>git commit</pre>
 not before setting your identity using:
 <pre>git config user.name "John Doe";
git config user.email john.doe@example.com;</pre>
</li>
<li><h5>pushing your commit upstream</h5>
To push your changes upstream (to the remote server) execute:
<pre>git push</pre>
not before setting the default push behavior:
<pre>git config push.default upstream;
git remote rm origin;
git remote add origin git@github.com:spacenut/tumbleweed.git;</pre>
</li>
<li>
<ol><li><h5>managing your authentication</h5>
You may be unable to pull and push from the remote origin. If this is the case, you may need to generate or link a public key to attach to your GitHub account. On Linux machines, execute:
<pre>ssh-keygen</pre>
 and follow the instructions listed. Alternatively, use an already generated public key.
</li>
<li>
Execute:
<pre>cat ~/.ssh/is_rsa.pub</pre>
 or wherever you chose to save the public key, and copy the contents into a new SSH key in <a about='_blank' href='https://github.com/settings/ssh'>account settings</a>.
</li>
</ol>

</li>
</ol>

<h4>Changing the app's port number</h4>

<p>By default, tumbleweed runs on port 8080, but it is possible to this by changing the port vagrant forwards in the Vagrantfile, along with one minor change to the app.js file</p>

<ol>
<li>open Vagrantfile in any text editor</li>
<li>find the line starting with:
<pre>config.vm.network :forwarded_port</pre>
 and change the guest and host ports to anything you choose</li>
<li>open app.js in ant text editor</li>
<li>on the line that starts with:
<pre>app.set('port', process.env.PORT || #####)</pre>
 change the number to the port you forwarded in step 2.</li>
</ol>
