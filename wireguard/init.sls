{% from "wireguard/map.jinja" import wireguard with context %}
{% set bootstrap = salt['pillar.get']('bootstrap') %}
{% set linux_headers_package = "linux-headers-" + grains.get('kernelrelease')|string %}

wireguard_software:
  pkg.installed:
    - pkgs:
      - wireguard
      - qrencode
      - {{ linux_headers_package }}
{%- if wireguard.get('repository', False) %}
    - require:
      - pkgrepo: wireguard_repo

wireguard_repo:
  pkgrepo.managed:
{%- for k,v in wireguard.repository.items() %}
    - {{ k }}: {{ v }}
{%- endfor %}
{%- endif %}

{%- for interface_name, interface_dict in salt['pillar.get']('wireguard:interfaces', {}).items() %}
{%- set interface_config = interface_dict.get('config', {}) %}

{%- if bootstrap == true %}
{%- set _dummy = interface_config.update({'PrivateKey': 'XXXXX_not_set_on_bootstrap_ami_XXXXX'}) %}
{%- endif %}

net.ipv4.ip_forward:
  sysctl.present:
    - value: 1

  {% if interface_dict.get('delete', False) %}
stop and disable wg-quick@{{interface_name}}:
  service.dead:
    - name: wg-quick@{{interface_name}}
    - enable: False
remove wireguard_interface_{{interface_name}}:
  file.absent:
    - name: /etc/wireguard/{{interface_name}}.conf
  {% else %}
    {% if not interface_dict.get('enable', True) %}
stop and disable wg-quick@{{interface_name}}:
  service.dead:
    - name: wg-quick@{{interface_name}}
    - enable: False
    {% else %}
      {% if bootstrap == false %}
restart wg-quick@{{interface_name}}:
  service.running:
    - name: wg-quick@{{interface_name}}
    - enable: True
    - watch:
      - file: wireguard_interface_{{interface_name}}_config
    - require:
      - pkg: wireguard_software
      {% endif %}
    {% endif %}

    {% if interface_dict.get('raw_config') %}
wireguard_interface_{{interface_name}}_config:
  file.managed:
    - name: /etc/wireguard/{{interface_name}}.conf
    - makedirs: True
    - contents_pillar: wireguard:interfaces:{{interface_name}}:raw_config
    - mode: 600
    {% else %}
wireguard_interface_{{interface_name}}_config:
  file.managed:
    - name: /etc/wireguard/{{interface_name}}.conf
    - makedirs: True
    - source: salt://wireguard/files/wg.conf
    - template: jinja
    - context:
      interface: {{interface_dict.get('config', {})}}
      peers: {{interface_dict.get('peers', [])}}
    - mode: 600
    {% endif %}

  {% endif %}

{%- endfor %}
