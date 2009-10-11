//  Copyright 2009 Richard Moreland.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

function toggleDrawer(name) {
    var drawerId = "drawer-body-" + name;
    var drawerToggleTextId = "drawer-toggle-" + name;
    
    var drawer = document.getElementById(drawerId);
    var drawerToggle = document.getElementById(drawerToggleTextId);
    
    if (drawer.style.display == 'block') {
        drawer.style.display = 'none';
        drawerToggle.innerHTML = "Show";
    } else {
        drawer.style.display = 'block';
        drawerToggle.innerHTML = "Hide";
    }
}

window.onload = init;