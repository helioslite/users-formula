include:
  - users.sudo

{% for name, user in pillar.get('users', {}).items() %}
{%- if user == None -%}
{%- set user = {} -%}
{%- endif -%}
{%- set home = user.get('home', "/home/%s" % name) -%}

{%- if 'prime_group' in user and 'name' in user['prime_group'] %}
{%- set user_group = user.prime_group.name -%}
{%- else -%}
{%- set user_group = name -%}
{%- endif %}

{% for group in user.get('groups', []) %}
{{ name }}_{{ group }}_group:
  group:
    - name: {{ group }}
    - present
{% endfor %}

{{ name }}_user:
  file.directory:
    - name: {{ home }}
    - user: {{ name }}
    - group: {{ user_group }}
    - mode: 0755
    - require:
      - user: {{ name }}
      - group: {{ user_group }}
  group.present:
    - name: {{ user_group }}
    {%- if 'prime_group' in user and 'gid' in user['prime_group'] %}
    - gid: {{ user['prime_group']['gid'] }}
    {%- elif 'uid' in user %}
    - gid: {{ user['uid'] }}
    {%- endif %}
  user.present:
    - name: {{ name }}
    - home: {{ home }}
    - shell: {{ user.get('shell', '/bin/bash') }}
    {% if 'system' in user -%}
    - system: {{ user['system'] }}
    {% endif -%}
    {% if 'password' in user -%}
    - password: {{ user['password'] }}
    {% endif -%}
    {% if 'enforce_password' in user -%}
    - enforce_password: {{ user['enforce_password'] }}
    {% endif -%}
    {% if 'uid' in user -%}
    - uid: {{ user['uid'] }}
    {% endif -%}
    {% if 'prime_group' in user and 'gid' in user['prime_group'] -%}
    - gid: {{ user['prime_group']['gid'] }}
    {% else -%}
    - gid_from_name: True
    {% endif -%}
    {% if 'fullname' in user %}
    - fullname: {{ user['fullname'] }}
    {% endif -%}
    - groups:
      - {{ user_group }}
      {% for group in user.get('groups', []) -%}
      - {{ group }}
      {% endfor %}
    - require:
      - group: {{ user_group }}
      {% for group in user.get('groups', []) -%}
      - group: {{ group }}
      {% endfor %}

user_keydir_{{ name }}:
  file.directory:
    - name: {{ home }}/.ssh
    - user: {{ name }}
    - group: {{ user_group }}
    - makedirs: True
    - mode: 700
    - require:
      - user: {{ name }}
      - group: {{ user_group }}
      {%- for group in user.get('groups', []) %}
      - group: {{ group }}
      {%- endfor %}

  {% if 'ssh_keys' in user %}
  {% set key_type = 'id_' + user.get('ssh_key_type', 'rsa') %}
user_{{ name }}_private_key:
  file.managed:
    - name: {{ home }}/.ssh/{{ key_type }}
    - user: {{ name }}
    - group: {{ user_group }}
    - mode: 600
    - contents_pillar: users:{{ name }}:ssh_keys:privkey
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ name }}_{{ group }}_group
      {% endfor %}
user_{{ name }}_public_key:
  file.managed:
    - name: {{ home }}/.ssh/{{ key_type }}.pub
    - user: {{ name }}
    - group: {{ user_group }}
    - mode: 644
    - contents_pillar: users:{{ name }}:ssh_keys:pubkey
    - require:
      - user: {{ name }}_user
      {% for group in user.get('groups', []) %}
      - group: {{ name }}_{{ group }}_group
      {% endfor %}
  {% endif %}


  {% if 'ssh_auth' in user %}
  {% for auth in user['ssh_auth'] %}
ssh_auth_{{ name }}_{{ loop.index0 }}:
  ssh_auth.present:
    {%- if auth is string %}
    - user: {{ name }}
    - name: {{ auth }}
    {%- else %}
    - user: {{ auth.get('user', name) }}
    - name: {{ auth['name'] }}
      {%- if 'enc' in auth %}
    - enc: {{ auth['enc'] }}
      {%- endif %}
      {%- if 'options' in auth %}
    - options:
        {%- for opt, val in auth['options'].iteritems() %}
      - {{ opt }}="{{ val }}"
        {%- endfor %}
      {%- endif %}
    {%- endif %}
    - require:
        - file: {{ name }}_user
        - user: {{ name }}_user
{% endfor %}
{% endif %}


{% if 'sudouser' in user and user['sudouser'] %}
sudoer-{{ name }}:
  file.managed:
    - name: /etc/sudoers.d/{{ name }}
    - user: root
    - group: root
    - mode: '0440'
{% if 'sudo_rules' in user %}
/etc/sudoers.d/{{ name }}:
  file.append:
    - text:
      {% for rule in user['sudo_rules'] %}
      - "{{ name }} {{ rule }}"
      {% endfor %}
    - require:
      - file: sudoer-defaults
      - file: sudoer-{{ name }}
{% endif %}
{% else %}
/etc/sudoers.d/{{ name }}:
  file.absent:
    - name: /etc/sudoers.d/{{ name }}
{% endif %}

{% endfor %}

{% for user in pillar.get('absent_users', []) %}
{{ user }}:
  user.absent
/etc/sudoers.d/{{ user }}:
  file.absent:
    - name: /etc/sudoers.d/{{ user }}
{% endfor %}

{% for group in pillar.get('absent_groups', []) %}
{{ group }}:
  group.absent
{% endfor %}

