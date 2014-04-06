<h3>tumbleweed</h3>

<p>You have landed on tumbleweed's public github repository. This document is for helping new developers get started with tumbleweed.</p>

<h4>A look at tumbleweed's dependencies</h4>
<p>As a convienience, and to make development easier across different platforms, this tumbleweed repository uses a <a href='https://www.virtualbox.org/'>virtual box</a> running <a href='http://www.vagrantup.com'>vagrant</a> to simulate a Linux 32-bit environment. If you do not have these installed already you may or may not have to get them to contribute to this project.</p>

<p>tumbleweed is currently running on node.js and is currently a node application. Therefore, you may have to install node.js</p>

<h5>Installing node.js</h5>
<ol>
<li>
<pre>sudo apt-get update;
sudo apt-get install –y python-software-properties python g++ make;
sudo add-apt-repository ppa:chris-lea/node.js;
sudo apt-get update;
sudo apt-get install nodejs;
</pre>
 in the app directory to get the reccomended version of node.js
</li>
<li>You ought to be able to execute:
<pre>node -v;
npm -v;</pre>
after completing step 1.</li>
</ol>

<h4>Getting started</h4>

<ol>
<li>clone the repo to local</li>
<li>execute:
<pre>vagrant up;
vagrant ssh;
cd ../../vagrant;
sudo npm -g install;</pre>
 in the repo directory to log in to the virtual machine and install node required packages</li>
<li>execute:
<pre>node app.js</pre>
 to run the tumbleweed app server</li>
<li>visit:
<pre>localhost:8080</pre>
 in any web browser to look at the site.</li>
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
