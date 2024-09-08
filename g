<?php

// Usage: C:\xampp\php\php.exe g scaffold "user|name,password,salt,emal,phone"

if (count($argv) == 1) {
  print_help();
  die();
} else if (count($argv) != 3) {
  echo 'Invalid arguments';
  die();
}

list($file, $command, $parameter) = $argv;
list($name, $columns) = parse_arg($parameter);
initialize_directories($name);
if ($command == 'scaffold') {
  append('application/doc/schema.sql', generate_schema($name, $columns));
  save('application/controllers/' . pluralize(ucwords($name)) . '.php', generate_controller($name));
  save('application/models/' . ucwords($name) . '_model.php', generate_model($name));
  save('application/helpers/' . $name . '_helper.php', generate_helper($name, $columns));
  save_views($name, $columns);
} else if ($command == 'controller') {
  save('application/controllers/' . ucwords($name) . 's.php', generate_controller($name));
} else if ($command == 'model') {
  save('application/models/' . ucwords($name) . '_model.php', generate_model($name));
} else if ($command == 'helper') {
  append('application/helpers/' . $name . '_helper.php', generate_helper($name, $columns));
} else if ($command == 'views') {
  save_views($name, $columns);
} else {
  echo 'Command not supported';
}

function print_help()
{
  echo 'Usage: g [command] [parameter]
  
  scaffold    Generate CodeIgniter components (controller=, model, views)
  controller  Create controller component
  helper      Create helper component
  model       Create model component
  views       Create view components
  
  parameter   The parameters that will be generated. See format example below
              
  Example:    "user|name,password,salt,email,phone"
              Will generate a user with properties name, password, salt, email and phone

';
}

function save_views($name, $columns)
{
  list($add, $edit, $index) = generate_views($name, $columns);
  save('application/views/' . pluralize($name) . '/add.php', $add);
  save('application/views/' . pluralize($name) . '/edit.php', $edit);
  save('application/views/' . pluralize($name) . '/index.php', $index);
}

function initialize_directories($name)
{
  make_dir('application/doc');
  make_dir('application/controllers');
  make_dir('application/models');
  make_dir('application/helpers');
  make_dir('application/views/' . pluralize($name));
}

function make_dir($dir)
{
  if (!file_exists($dir)) {
    mkdir($dir, 0755, true);
  }
}

function append($file, $contents)
{
  echo 'Adding ' . $file . "...\n";
  file_put_contents($file, $contents, FILE_APPEND | LOCK_EX);
}

function save($file, $contents)
{
  echo 'Saving ' . $file . '... ';
  if (file_exists($file)) {
    echo 'file exists';
  } else {
    file_put_contents($file, $contents, LOCK_EX);
    echo 'OK';
  }
  echo "\n";
}

function get_sql_type($type)
{
  if ($type == 'string') {
    return 'varchar(255)';
  }
  return $type;
}

function pluralize($word)
{
  $plural = [
    '/(quiz)$/i' => "$1zes",
    '/^(ox)$/i' => "$1en",
    '/([m|l])ouse$/i' => "$1ice",
    '/(matr|vert|ind)(ix|ex)$/i' => "$1ices",
    '/(x|ch|ss|sh)$/i' => "$1es",
    '/([^aeiouy]|qu)y$/i' => "$1ies",
    '/(hive)$/i' => "$1s",
    '/(?:([^f])fe|([lr])f)$/i' => "$1$2ves",
    '/(shea|lea|loa|thie)f$/i' => "$1ves",
    '/sis$/i' => "ses",
    '/([ti])um$/i' => "$1a",
    '/(tomat|potat|ech|her|vet)o$/i' => "$1oes",
    '/(bu)s$/i' => "$1ses",
    '/(alias)$/i' => "$1es",
    '/(octop)us$/i' => "$1i",
    '/(ax|test)is$/i' => "$1es",
    '/(us)$/i' => "$1es",
    '/s$/i' => "s",
    '/$/' => "s"
  ];

  $irregular = [
    'move' => 'moves',
    'foot' => 'feet',
    'goose' => 'geese',
    'sex' => 'sexes',
    'child' => 'children',
    'man' => 'men',
    'tooth' => 'teeth',
    'person' => 'people'
  ];

  $uncountable = [
    'sheep',
    'fish',
    'deer',
    'series',
    'species',
    'money',
    'rice',
    'information',
    'equipment'
  ];

  if (in_array(strtolower($word), $uncountable)) {
    return $word;
  }

  foreach ($irregular as $pattern => $result) {
    $pattern = '/' . $pattern . '$/i';

    if (preg_match($pattern, $word)) {
      return preg_replace($pattern, $result, $word);
    }
  }

  foreach ($plural as $pattern => $result) {
    if (preg_match($pattern, $word)) {
      return preg_replace($pattern, $result, $word);
    }
  }

  return $word;
}

function generate_schema($name, $columns)
{
  $cols = '';
  $i = 0;
  foreach ($columns as $column) {
    $sql_type = get_sql_type($column->type);
    $not_null = $column->not_null ? ' not null' : '';
    $primary_key = $column->primary_key ? ' primary key' : '';
    $auto_increment = $column->auto_increment ? ' auto_increment' : '';
    $cols .= "  $column->name $sql_type" . $not_null . $primary_key . $auto_increment;
    if ($i++ < count($columns) - 1) {
      $cols .= ",\n";
    }
  }
  $str = 'create table __TABLE__(
__COLS__
);

';
  $str = str_replace("__TABLE__", pluralize($name), $str);
  $str = str_replace("__COLS__", $cols, $str);
  $str = str_replace('"', "'", $str);
  return $str;
}

function parse_arg($arg)
{
  list($name, $cols) = explode('|', $arg);
  $cols = explode(',', $cols);
  $columns = array();
  foreach ($cols as $col) {
    $x = explode(':', $col);
    if (count($x) > 1) {
      $column = new Column($x[0], $x[1]);
    } else {
      $column = new Column($x[0], 'string');
    }
    $columns[] = $column;
  }
  if (!column_name_exists('id', $columns)) {
    array_unshift($columns, new Column('id', 'integer', true, true, true));
  }
  return array($name, $columns);
}

function column_name_exists($name, $columns)
{
  foreach ($columns as $col) {
    if ($col->name == $name) {
      return true;
    }
  }
  return false;
}

class Column
{
  var $name;
  var $type;
  var $not_null;
  var $primary_key;
  var $auto_increment;

  function __construct($name, $type, $not_null = false, $primary_key = false, $auto_increment = false)
  {
    $this->name = $name;
    $this->type = $type;
    $this->not_null = $not_null;
    $this->primary_key = $primary_key;
    $this->auto_increment = $auto_increment;
  }
}

function generate_views($name, $columns)
{
  $cols = '';
  $i = 0;
  foreach ($columns as $column) {
    $cols .= "<p>" . ucwords($column->name) . "<br>
  <?php echo form_input('" . $column->name . "', " . '$this->input->post(' . "'" . $column->name . "'" . ')' . "); ?>
  <?php echo form_error('" . $column->name . "'); ?>
</p>";
    if ($i++ < count($columns) - 1) {
      $cols .= "\n";
    }
  }
  $add = "<h3>Add __VAR__</h3>
<?php echo form_open('__VARS__/add'); ?>
__COLS__
<p>
  <?php echo form_submit('submit', 'Save changes'); ?>
  or <?php echo anchor('__VARS__', 'cancel'); ?>
</p>
<?php echo form_close(); ?>";
  $add = str_replace("__VAR__", $name, $add);
  $add = str_replace("__VARS__", pluralize($name), $add);
  $add = str_replace("__COLS__", $cols, $add);

  $cols = '';
  $i = 0;
  foreach ($columns as $column) {
    $cols .= "<p>" . ucwords($column->name) . "<br>
  <?php echo form_input('" . $column->name . "', " . '$' . $name . '->' . $column->name . "); ?>
  <?php echo form_error('" . $column->name . "'); ?>
</p>";
    if ($i++ < count($columns) - 1) {
      $cols .= "\n";
    }
  }
  $edit = "<h3>Edit __VAR__</h3>
<?php echo form_open('__VARS__/edit/' . " . '$__VAR__->id' . "); ?>
__COLS__
<p>
  <?php echo form_submit('submit', 'Save changes'); ?>
  or <?php echo anchor('__VARS__', 'cancel'); ?>
</p>
<?php echo form_close(); ?>";
  $edit = str_replace("__VAR__", $name, $edit);
  $edit = str_replace("__VARS__", pluralize($name), $edit);
  $edit = str_replace("__COLS__", $cols, $edit);

  $heads = '';
  $bodies = '';
  $i = 0;
  foreach ($columns as $column) {
    $heads .= '    <th>' . ucwords($column->name) . '</th>';
    $bodies .= '    <td><?php echo $' . $name . '->' . $column->name . '; ?></td>';
    if ($i++ < count($columns) - 1) {
      $heads .= "\n";
      $bodies .= "\n";
    }
  }
  $index = "<h3>__NAME__</h3>
<p><?php echo anchor('__VARS__/add', 'Add __NAME__'); ?></p>
<table>
  <tr>
__HEADS__
    <th></th>
  </tr>
  <?php foreach (" . '$' . pluralize($name) . ' as $' . $name . '): ?>' . "
  <tr>
__BODY__
    <td>
      <?php echo anchor('__VARS__/edit/' . " . '$' . $name . '->id' . ", 'Edit'); ?>
      <a href='javascript:void(0);' onclick=" . '"delete__NAME__(' . "'" . '<?php echo $' . $name . '->id; ?>' . "'" . ', <?php echo $' . $name . '->id; ?>);' . '" title="Delete">Delete</a>' . "
    </td>
  </tr>
  <?php endforeach; ?>
</table>

<script>
  var url = '<?php echo base_url(); ?>';
  function delete__NAME__(name, id) {
    var c = confirm('Do you really want to delete ' + name + '?');
    if (c === true) {
      window.location = url + '" . pluralize($name) . "/delete/' + id;
    } else {
      return false;
    }
  }
</script>";
  $index = str_replace("__NAME__", ucwords(pluralize($name)), $index);
  $index = str_replace("__VAR__", $name, $index);
  $index = str_replace("__VARS__", pluralize($name), $index);
  $index = str_replace("__HEADS__", $heads, $index);
  $index = str_replace("__BODY__", $bodies, $index);

  return array(
    $add,
    $edit,
    $index
  );
}

function generate_helper($name, $columns)
{
  $cols = '';
  $vals = '';
  $i = 1;
  foreach ($columns as $column) {
    if ($column->name != 'id') {
      $cols .= '    "' . $column->name . '" => $obj->input->post("' . $column->name . '"),';
      $vals .= '  $obj->form_validation->set_rules("' . $column->name . '", "' . ucwords($column->name) . '", "required");';
      if ($i < count($columns)) {
        $cols .= "\n";
        $vals .= "\n";
      }
    }
    $i++;
  }
  $str = '<?php

function __VAR___form() {
  $obj = &get_instance();
  return array(
__COLS__
  );
}

function __VAR___form_validate() {
  $obj = &get_instance();
__VALS__
}';
  $str = str_replace("__NAME__", ucwords($name), $str);
  $str = str_replace("__VAR__", $name, $str);
  $str = str_replace("__COLS__", $cols, $str);
  $str = str_replace("__VALS__", $vals, $str);
  $str = str_replace('"', "'", $str);
  return $str;
}

function generate_controller($model)
{
  $str = '<?php

class __NAME__ extends CI_Controller {

  function __construct() {
    parent::__construct();
    $this->load->library("form_validation");
    $this->load->library("layout");
    $this->load->model("__VAR___model");
    $this->load->helper("__VAR__");
    $this->load->model("__VAR___model");
  }

  function index() {
    $data["__VARS__"] = $this->__VAR___model->find_all();
    $this->layout->view("__VARS__/index", $data);
  }

  function add() {
    if ($this->input->post()) {
      $__VAR__ = __VAR___form();
      __VAR___form_validate();
      if ($this->form_validation->run() != FALSE) {
        $this->__VAR___model->save($__VAR__);
        redirect("__VARS__");
      }
    }
    $this->layout->view("__VARS__/add");
  }

  function edit($id) {
    if ($this->input->post()) {
      $__VAR__ = __VAR___form();
      __VAR___form_validate();
      if ($this->form_validation->run() != FALSE) {
        $this->__VAR___model->update($__VAR__, $id);
        redirect("__VARS__");
      }
    }
    $data["__VAR__"] = $this->__VAR___model->read($id);
    $this->layout->view("__VARS__/edit", $data);
  }

  function delete($id) {
    $this->__VAR___model->delete($id);
    redirect("__VARS__");
  }

}';
  $str = str_replace("__NAME__", pluralize(ucwords($model)), $str);
  $str = str_replace("__VAR__", $model, $str);
  $str = str_replace("__VARS__", pluralize($model), $str);
  $str = str_replace('"', "'", $str);
  return $str;
}

function generate_model($model)
{
  $str = '<?php

class __NAME___model extends CI_Model {

  function __construct() {
    $this->load->database();
  }

  function find_all() {
    return $this->db->get("__VARS__")->result();
  }

  function read($id) {
    return $this->db->get_where("__VARS__", array("id" => $id))->row();
  }

  function save($__VAR__) {
    $this->db->insert("__VARS__", $__VAR__);
  }

  function update($__VAR__, $id) {
    $this->db->update("__VARS__", $__VAR__, array("id" => $id));
  }

  function delete($id) {
    $this->db->delete("__VARS__", array("id" => $id));
  }

}';
  $str = str_replace("__NAME__", ucwords($model), $str);
  $str = str_replace("__VAR__", $model, $str);
  $str = str_replace("__VARS__", pluralize($model), $str);
  $str = str_replace('"', "'", $str);
  return $str;
}
