Automated Eclipse/Franca environment installation
=================================================

Scripts related to Franca IDL installation

Instructions for Virtual Machine creation
-----------------------------------------

1. Get Vagrant

   for example:
   $ sudo apt-get install vagrant
    or
   $ sudo yum install vagrant

2. Install the latest VirtualBox

3. Run Vagrant up:

   $ vagrant up

   The first time it will download the base VM "box" which
   is currently an Ubuntu system.

   Feel free to replace it with another box of another distro, but the
   provisioning using apt-get may need changes then.  Pull requests
   welcome.

   NOTE: There will be some errors towards the end of the provisioning which
   seems to be due to vagrant provisioning not running in a normal interactive
   shell?

   You can ignore those errors.  Of course you may have some other error that I
   have not seen yet, but using vagrant and a known base box this should be
   quite foolproof.

4. Stop the VM which is now running headless:

   $ vagrant halt

5. Locate your VM in VirtualBox GUI and boot it normally (i.e. not headless)

   You should see an LXDE graphical shell asking you to select user.

   Login as vagrant, password vagrant

6. Enjoy testing Franca environment!

   Note: The workspace is prepared at /home/vagrant/workspace,
   but this is also eclipse default, so just hit OK

7. To run Franca examples you must manually import them into the
   workspace. The instructions can be found towards the end of script.sh


Tweaking settings
------------------

   The VM is configured with 1.5 GB RAM.  You may want to modify that setting
   in Vagrantfile or change the VM settings manually in VirtualBox if you are
   doing large builds.  I am not sure what is required except that 512MB was
   not enough, and 1.5G worked fine for running Franca tests.

Sharing files
-------------

   Note, in a Vagrant box you can share files through the /vagrant directory:
   On host: it's THIS directory, where you have Vagrantfile and this README
   On Virtual Machine:   Mounted at /vagrant

   You can also get a direct command line on the VM using vagrant ssh, but
   that's not too useful for running eclipse:

   $ vagrant ssh

   Read Vagrant documentation to learn more: http://www.vagrantup.com/

Installation on bare metal
--------------------------

Finally you may use ./script.sh (and CONFIG) directly on any machine (VM or
bare metal) without using Vagrant to simply automate Franca install.
Make sure to modify the install location and workspace name in CONFIG to your
liking.

script.sh does not use any package manager so it should run on several
distros. It is developed on Fedora but tested also on Ubuntu (using the 
Vagrant wrapper)

The script downloads and installs eclipse.  If you have an Eclipse environment
already you probably need to follow a manual procedure using Franca
documentation to get Franca into your "standard" Eclipse.
