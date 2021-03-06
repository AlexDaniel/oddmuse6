# Oddmuse is a wiki engine
# Copyright (C) 2018  Alex Schroeder <alex@gnu.org>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
# for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

use Oddmuse::Storage::File::Test;
use Oddmuse::Storage;
use Oddmuse::Routes;
use Cro::HTTP::Test;
use Test;

my $root = get-random-wiki-directory;

my $storage = Oddmuse::Storage.new;

my $id = 'Home';

# Check whether the view and history actions correctly reflect locked state

test-service routes(), {
  test get("/view/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'Edit' /;
  test get("/history/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'This page editable' /;
}

$storage.lock-page: $id;
ok($storage.is-locked($id), "page locked");

test-service routes(), {
  test get("/view/$id"),
      status => 200,
      content-type => 'text/html',
      body => { $_ !~~ / 'Edit' / };
  test get("/history/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'This page is locked' /;
}

$storage.unlock-page: $id;
nok($storage.is-locked($id), "page unlocked (1)");

test-service routes(), {
  test get("/view/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'Edit' /;
  test get("/history/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'This page editable' /;
}

# Check whether the lock and unlock actions are protected by a password

%*ENV<ODDMUSE_PASSWORD> = 'left';

test-service routes(), {
  test post("/lock/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'Administrator Password' /;
  test post("/lock/$id", json => { :pw('wrong') }),
      status => 200,
      content-type => 'text/html',
      body => / 'Administrator Password' /;
  test post("/lock/$id", json => { :pw('left') }),
      status => 200,
      content-type => 'text/html',
      # we can see the edit link because we're admins!
      body => { $_ ~~ / 'Welcome' / && $_ ~~ / 'Edit' / };
}

ok($storage.is-locked($id), "page locked");

test-service routes(), {
  test post("/unlock/$id"),
      status => 200,
      content-type => 'text/html',
      body => / 'Administrator Password' /;
  test post("/unlock/$id", json => { :pw('wrong') }),
      status => 200,
      content-type => 'text/html',
      body => / 'Administrator Password' /;
  test post("/unlock/$id", json => { :pw('left') }),
      status => 200,
      content-type => 'text/html',
      body => { $_ ~~ / 'Welcome' / && $_ ~~ / 'Edit' / };
}

nok($storage.is-locked($id), "page unlocked (2)");

# Check whether the save actions correctly checks whether the page is locked

$storage.lock-page: $id;

test-service routes(), {
  test post('/save',
	    json => { :$id, :text('Hallo'), :summary('testing'), }),
      status => 200,
      content-type => 'text/html',
      body => / 'Administrator Password' /;
  test post('/save',
	    json => { :$id, :text('Hallo'), :summary('testing'), :pw('left')}),
      status => 200,
      content-type => 'text/html',
      body => / 'Hallo' /;
}

$storage.unlock-page: $id;
nok($storage.is-locked($id), "page unlocked (3)");

test-service routes(), {
  test post('/save',
	    json => { :$id, :text('Morgen'), :summary('testing'), }),
      status => 200,
      content-type => 'text/html',
      body => / 'Morgen' /;
}

done-testing;
