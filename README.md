<h3>tumbleweed</h3>

<p>You have landed on tumbleweed's public github repository. This document is for helping new developers get started with tumbleweed.</p>

<h4>Getting started</h4>

<ol>
<li>clone the repo to local</li>
<li>execute:
<pre>vagrant up;</pre>
<pre>vagrant ssh;</pre>
<pre>cd ../../vagrant;</pre>
<pre>sudo npm -g install</pre>
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
